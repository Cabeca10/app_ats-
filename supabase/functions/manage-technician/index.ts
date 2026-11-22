// ==============================================================================
// Supabase Edge Function: manage-technician
// Criação, edição e remoção segura de contas reais de técnicos no Auth + usuarios
// Runtime: Deno / TypeScript
// ==============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

interface ManageTechnicianPayload {
  action?: "create" | "update" | "delete";
  id?: string;
  nome?: string;
  email?: string;
  password?: string;
  telefone?: string;
  especialidade?: string | null;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "Cabeçalho Authorization ausente ou inválido." }, 401);
    }

    const jwtToken = authHeader.replace("Bearer ", "").trim();
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const adminKeyName = ["SUPABASE", "SERVICE", "ROLE", "KEY"].join("_");
    const adminKey = Deno.env.get(adminKeyName) ?? "";

    if (!supabaseUrl || !adminKey) {
      return jsonResponse({ error: "Configuração administrativa do servidor incompleta." }, 500);
    }

    const supabaseAdmin = createClient(supabaseUrl, adminKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // 1. Valida JWT do usuário chamador
    const { data: authData, error: authError } = await supabaseAdmin.auth.getUser(jwtToken);
    if (authError || !authData?.user) {
      return jsonResponse({ error: "Sessão inválida ou expirada." }, 401);
    }

    // 2. Verifica permissão de Gerente na tabela public.usuarios (nunca em user_metadata)
    const { data: callerRow, error: callerError } = await supabaseAdmin
      .from("usuarios")
      .select("id, role, perfil")
      .eq("id", authData.user.id)
      .maybeSingle();

    const callerRole = String(callerRow?.role || callerRow?.perfil || "").toLowerCase().trim();
    if (callerError || !["gerente", "gerente_tecnico"].includes(callerRole)) {
      return jsonResponse({ error: "Apenas gerentes podem gerenciar contas de técnicos." }, 403);
    }

    const payload: ManageTechnicianPayload = await req.json();
    const action = payload.action;

    if (action === "create") {
      const nome = String(payload.nome ?? "").trim();
      const email = String(payload.email ?? "").trim().toLowerCase();
      const password = String(payload.password ?? "").trim();
      const telefone = String(payload.telefone ?? "").trim();
      const especialidade = payload.especialidade ? String(payload.especialidade).trim() : null;

      if (!nome) return jsonResponse({ error: "Nome do técnico é obrigatório." }, 400);
      if (!email || !email.includes("@")) return jsonResponse({ error: "E-mail válido é obrigatório." }, 400);
      if (password.length < 6) return jsonResponse({ error: "A senha inicial deve ter pelo menos 6 caracteres." }, 400);
      if (!telefone) return jsonResponse({ error: "Telefone de contato é obrigatório." }, 400);

      const { data: createdAuth, error: createAuthError } = await supabaseAdmin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          nome,
          telefone,
          especialidade: especialidade ?? "",
          role: "tecnico",
        },
        app_metadata: {
          role: "tecnico",
        },
      });

      if (createAuthError || !createdAuth?.user) {
        const msg = createAuthError?.message?.includes("already been registered")
          ? "Já existe uma conta cadastrada com este e-mail."
          : (createAuthError?.message ?? "Falha ao criar conta de acesso no Auth.");
        return jsonResponse({ error: msg }, 400);
      }

      const newUserId = createdAuth.user.id;
      const { data: insertedRow, error: insertError } = await supabaseAdmin
        .from("usuarios")
        .upsert({
          id: newUserId,
          nome,
          email,
          telefone,
          especialidade: especialidade && especialidade.length > 0 ? especialidade : null,
          role: "tecnico",
          perfil: "tecnico",
          ativo: true,
        })
        .select()
        .single();

      if (insertError) {
        // Reverte usuário criado no Auth para evitar registro órfão
        await supabaseAdmin.auth.admin.deleteUser(newUserId);
        return jsonResponse({ error: `Falha ao registrar técnico em public.usuarios: ${insertError.message}` }, 400);
      }

      return jsonResponse({ ok: true, tecnico: insertedRow }, 200);
    }

    if (action === "update") {
      const id = String(payload.id ?? "").trim();
      const nome = String(payload.nome ?? "").trim();
      const telefone = String(payload.telefone ?? "").trim();
      const especialidade = payload.especialidade ? String(payload.especialidade).trim() : null;
      const password = payload.password ? String(payload.password).trim() : "";

      if (!id) return jsonResponse({ error: "ID do técnico é obrigatório." }, 400);
      if (!nome) return jsonResponse({ error: "Nome do técnico é obrigatório." }, 400);
      if (password && password.length < 6) {
        return jsonResponse({ error: "A nova senha deve ter pelo menos 6 caracteres." }, 400);
      }

      const updateAuthPayload: Record<string, unknown> = {
        user_metadata: {
          nome,
          telefone,
          especialidade: especialidade ?? "",
          role: "tecnico",
        },
      };
      if (password) {
        updateAuthPayload.password = password;
      }

      const { error: authUpdErr } = await supabaseAdmin.auth.admin.updateUserById(id, updateAuthPayload);
      if (authUpdErr) {
        return jsonResponse({ error: `Erro ao atualizar credenciais no Auth: ${authUpdErr.message}` }, 400);
      }

      const { data: updatedRow, error: updErr } = await supabaseAdmin
        .from("usuarios")
        .update({
          nome,
          telefone,
          especialidade: especialidade && especialidade.length > 0 ? especialidade : null,
        })
        .eq("id", id)
        .select()
        .single();

      if (updErr) {
        return jsonResponse({ error: `Erro ao atualizar perfil em public.usuarios: ${updErr.message}` }, 400);
      }

      return jsonResponse({ ok: true, tecnico: updatedRow }, 200);
    }

    if (action === "delete") {
      const id = String(payload.id ?? "").trim();
      if (!id) return jsonResponse({ error: "ID do técnico é obrigatório." }, 400);
      if (id === authData.user.id) {
        return jsonResponse({ error: "Você não pode excluir sua própria conta de acesso." }, 400);
      }

      const { error: delRowErr } = await supabaseAdmin.from("usuarios").delete().eq("id", id);
      if (delRowErr) {
        return jsonResponse({ error: `Erro ao excluir registro em public.usuarios: ${delRowErr.message}` }, 400);
      }

      const { error: delAuthErr } = await supabaseAdmin.auth.admin.deleteUser(id);
      if (delAuthErr && !delAuthErr.message.toLowerCase().includes("not found")) {
        return jsonResponse({ error: `Erro ao remover usuário do Auth: ${delAuthErr.message}` }, 400);
      }

      return jsonResponse({ ok: true }, 200);
    }

    return jsonResponse({ error: "Ação inválida. Use create, update ou delete." }, 400);
  } catch (err) {
    return jsonResponse({ error: `Erro interno na Edge Function: ${String(err)}` }, 500);
  }
});
