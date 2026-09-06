// ==============================================================================
// Supabase Edge Function: send-orcamento-email
// Envio seguro de e-mails de confirmação de orçamento aprovado com link do PDF
// Runtime: Deno / TypeScript
// ==============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface OrcamentoEmailPayload {
  chamadoId: string;
  numeroAts: string;
  tokenUrl: string;
  pdfUrl: string;
  razaoSocial: string;
  clienteEmail: string;
  managerEmail: string;
  responsavelNome: string;
}

serve(async (req: Request) => {
  // Tratamento de CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload: OrcamentoEmailPayload = await req.json();

    const {
      numeroAts,
      razaoSocial,
      clienteEmail,
      managerEmail,
      pdfUrl,
      responsavelNome,
    } = payload;

    if (!numeroAts || !pdfUrl) {
      return new Response(
        JSON.stringify({ error: "Parâmetros obrigatórios ausentes (numeroAts, pdfUrl)" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Configuração de envio via Resend (ou mock para desenvolvimento)
    const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");

    const emailSubject = `[ATS Serviços] Orçamento Aprovado - O.S. Nº ${numeroAts} (${razaoSocial})`;

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
            <h1>ATS Serviços</h1>
            <p>Equipamentos e Peças Ltda — Pmach Group</p>
          </div>
          <div class="content">
            <span class="badge">✓ Orçamento Aprovado pelo Cliente</span>
            <h2>Confirmação de Aceite de Atendimento</h2>
            <p>Olá,</p>
            <p>O orçamento referente à Ordem de Serviço <strong>Nº ${numeroAts}</strong> para a empresa <strong>${razaoSocial}</strong> foi formalmente aceito e assinado digitalmente.</p>
            
            <div class="info-box">
              <strong>Detalhes da Assinatura:</strong><br>
              • <strong>Responsável:</strong> ${responsavelNome || "Representante Autorizado"}<br>
              • <strong>Ordem de Serviço:</strong> Nº ${numeroAts}<br>
              • <strong>Status Atual:</strong> Aprovado - Aguardando Atribuição Técnica<br>
              • <strong>Autenticação:</strong> Assinatura Digital com Carimbo de Tempo
            </div>

            <div class="button-container">
              <a href="${pdfUrl}" target="_blank" class="btn-download">
                Visualizar / Baixar Orçamento Assinado (PDF)
              </a>
            </div>

            <p style="font-size: 13px; color: #64748b;">
              O chamado já está disponível no painel de gestão para que o Gerente encaminhe o técnico responsável para início dos serviços.
            </p>
          </div>
          <div class="footer">
            ATS Serviços Equipamentos e Peças Ltda | Atendimento Técnico Especializado<br>
            Este é um e-mail automático gerado pelo sistema de Ordens de Serviço.
          </div>
        </div>
      </body>
      </html>
    `;

    let emailSent = false;
    let resendResponse = null;

    if (RESEND_API_KEY) {
      // Disparo de e-mail via API Resend
      const recipients = [clienteEmail, managerEmail].filter(Boolean);
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${RESEND_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: "ATS Serviços <atendimento@atsservicos.com.br>",
          to: recipients,
          subject: emailSubject,
          html: emailHtmlBody,
        }),
      });

      resendResponse = await res.json();
      emailSent = res.ok;
    } else {
      // Fallback em ambiente de homologação / desenvolvimento local
      console.log(`[SIMULAÇÃO EMAIL] E-mail preparado para: ${clienteEmail} e ${managerEmail}`);
      console.log(`[SIMULAÇÃO EMAIL] Assunto: ${emailSubject}`);
      console.log(`[SIMULAÇÃO EMAIL] Link do PDF: ${pdfUrl}`);
      emailSent = true;
      resendResponse = { mock: true, sentAt: new Date().toISOString() };
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "E-mails de notificação processados com sucesso",
        emailSent,
        data: resendResponse,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: any) {
    console.error("Erro ao processar envio de e-mail de orçamento:", err);
    return new Response(
      JSON.stringify({ error: err.message || "Erro interno do servidor" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
