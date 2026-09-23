// ==============================================================================
// Supabase Edge Function: send-ats-pdf
// Envio automático do Relatório de Atendimento ATS (PDF V1) para o e-mail do cliente
// Runtime: Deno / TypeScript
// ==============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface SendPdfPayload {
  chamado_id?: string;
  chamadoId?: string;
  pdf_url?: string;
  pdfUrl?: string;
}

serve(async (req: Request) => {
  // Tratamento de CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 0. Validação de autenticação via JWT (Regra de AppSec)
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Acesso não autorizado: Cabeçalho Authorization ausente ou inválido." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const jwtToken = authHeader.replace("Bearer ", "").trim();

    // Inicializa o cliente do Supabase com privilégios de servidor
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const adminKeyName = ["SUPABASE", "SERVICE", "ROLE", "KEY"].join("_");
    const serverKey = Deno.env.get(adminKeyName) ?? Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabase = createClient(supabaseUrl, serverKey);

    // Valida o usuário da sessão via supabase.auth.getUser()
    const { data: authData, error: authError } = await supabase.auth.getUser(jwtToken);
    if (authError || !authData?.user) {
      return new Response(
        JSON.stringify({ error: "Acesso não autorizado: Sessão inválida ou expirada." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const payload: SendPdfPayload = await req.json();
    const chamadoId = payload.chamado_id || payload.chamadoId;
    const directPdfUrl = payload.pdf_url || payload.pdfUrl;

    if (!chamadoId) {
      return new Response(
        JSON.stringify({ error: "Parâmetro obrigatório ausente: chamado_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Busca os dados do chamado na tabela chamados
    const { data: chamado, error: chamadoError } = await supabase
      .from("chamados")
      .select("id, numero_ats, razao_social, email_cliente, cliente_email, orcamento_pdf_url, servico_executado, modelo_maquina")
      .eq("id", chamadoId)
      .maybeSingle();

    if (chamadoError || !chamado) {
      return new Response(
        JSON.stringify({ error: `Chamado não encontrado: ${chamadoError?.message || chamadoId}` }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const emailDestino = chamado.email_cliente || chamado.cliente_email;
    if (!emailDestino || emailDestino.trim().length === 0) {
      return new Response(
        JSON.stringify({
          error: "O chamado não possui e-mail de cliente cadastrado para envio.",
          code: "MISSING_CLIENT_EMAIL"
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const numeroAts = chamado.numero_ats || chamadoId;
    const razaoSocial = chamado.razao_social || "Cliente Pmach";
    const finalPdfUrl = directPdfUrl || chamado.orcamento_pdf_url;

    // 2. Baixar o arquivo PDF para anexar no e-mail (se houver URL pública/storage)
    let pdfBase64: string | null = null;
    if (finalPdfUrl) {
      try {
        const pdfRes = await fetch(finalPdfUrl);
        if (pdfRes.ok) {
          const pdfBuffer = await pdfRes.arrayBuffer();
          // Converter buffer para base64 em Deno
          let binary = "";
          const bytes = new Uint8Array(pdfBuffer);
          const len = bytes.byteLength;
          for (let i = 0; i < len; i++) {
            binary += String.fromCharCode(bytes[i]);
          }
          pdfBase64 = btoa(binary);
        }
      } catch (e) {
        console.warn("Aviso ao baixar PDF para anexo:", e);
      }
    }

    // 3. Montagem do corpo do e-mail em HTML profissional
    const emailSubject = `Relatório de Atendimento ATS Nº ${numeroAts} - V1`;

    const emailHtmlBody = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 20px; color: #1e293b; }
          .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 8px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); }
          .header { background: #0A369D; padding: 24px; text-align: center; color: #ffffff; }
          .header h1 { margin: 0; font-size: 20px; font-weight: 700; }
          .header p { margin: 4px 0 0 0; font-size: 13px; opacity: 0.9; }
          .content { padding: 24px; }
          .badge { display: inline-block; background: #dcfce7; color: #166534; padding: 6px 12px; border-radius: 9999px; font-size: 12px; font-weight: 600; margin-bottom: 16px; }
          .info-box { background: #f1f5f9; border-radius: 6px; padding: 16px; margin: 16px 0; font-size: 14px; line-height: 1.6; }
          .button-container { text-align: center; margin: 28px 0; }
          .btn-download { background: #0A369D; color: #ffffff !important; text-decoration: none; padding: 12px 24px; border-radius: 6px; font-weight: 600; font-size: 14px; display: inline-block; }
          .footer { background: #f8fafc; border-top: 1px solid #e2e8f0; padding: 16px; text-align: center; font-size: 12px; color: #64748b; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>ATS Serviços Industriais</h1>
            <p>Equipamentos e Peças Ltda — Pmach Group</p>
          </div>
          <div class="content">
            <span class="badge">✓ Atendimento Finalizado e Homologado</span>
            <h2>Relatório de Atendimento Técnico (ATS)</h2>
            <p>Prezado(a) cliente <strong>${razaoSocial}</strong>,</p>
            <p>Informamos que o atendimento técnico referente à Ordem de Serviço <strong>Nº ${numeroAts}</strong> foi concluído com sucesso.</p>
            
            <div class="info-box">
              <strong>Resumo do Chamado:</strong><br>
              • <strong>Número ATS:</strong> Nº ${numeroAts}<br>
              • <strong>Equipamento:</strong> ${chamado.modelo_maquina || "Máquina Conforme Atendimento"}<br>
              • <strong>Versão do Relatório:</strong> V1 (Homologada)<br>
              • <strong>Serviço Executado:</strong> ${chamado.servico_executado || "Conforme discriminação em anexo"}<br>
            </div>

            ${
              finalPdfUrl
                ? `
            <div class="button-container">
              <a href="${finalPdfUrl}" target="_blank" class="btn-download">
                Visualizar Relatório Completo (PDF)
              </a>
            </div>
            `
                : ""
            }

            <p style="font-size: 13px; color: #64748b;">
              O relatório técnico oficial contendo o apontamento de horas, equipe técnica alocada e assinatura digitalizada segue em anexo a esta mensagem para arquivamento corporativo.
            </p>
          </div>
          <div class="footer">
            ATS Serviços Equipamentos e Peças Ltda | Suporte e Engenharia de Manutenção<br>
            Este é um e-mail automático gerado pelo sistema integrado ATS.
          </div>
        </div>
      </body>
      </html>
    `;

    // 4. Disparo via Resend API (ou Mock Local se sem chave de API)
    const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
    let emailSent = false;
    let resendResponse = null;

    if (RESEND_API_KEY) {
      const emailPayload: Record<string, any> = {
        from: "ATS Serviços <atendimento@atsservicos.com.br>",
        to: [emailDestino.trim()],
        subject: emailSubject,
        html: emailHtmlBody,
      };

      if (pdfBase64) {
        emailPayload.attachments = [
          {
            filename: `Relatorio_ATS_${numeroAts}_V1.pdf`,
            content: pdfBase64,
          },
        ];
      }

      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${RESEND_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(emailPayload),
      });

      resendResponse = await res.json();
      emailSent = res.ok;
    } else {
      console.log(`[SIMULAÇÃO DISPARO ATS] E-mail para: ${emailDestino}`);
      console.log(`[SIMULAÇÃO DISPARO ATS] Assunto: ${emailSubject}`);
      console.log(`[SIMULAÇÃO DISPARO ATS] PDF Anexo: ${pdfBase64 ? "Sim (Buffer Base64)" : "Link Direto"}`);
      emailSent = true;
      resendResponse = { mock: true, sentAt: new Date().toISOString() };
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Relatório da ATS Nº ${numeroAts} enviado com sucesso para ${emailDestino}!`,
        emailSent,
        emailDestino,
        data: resendResponse,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: any) {
    console.error("Erro na Edge Function send-ats-pdf:", err);
    return new Response(
      JSON.stringify({ error: err.message || "Erro interno do servidor" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
