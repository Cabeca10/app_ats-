-- ==============================================================================
-- Migração: Garantir Acesso do Cliente ao Orçamento e Colunas de Suporte
-- Projeto: Pmach ATS Digital
-- Arquivo: supabase/migrations/20261102_orcamento_client_access.sql
-- ==============================================================================

-- 1. Garantir existência da coluna pdf_url para compatibilidade direta
ALTER TABLE public.chamados
ADD COLUMN IF NOT EXISTS pdf_url TEXT;

-- 2. Políticas RLS para Acesso Público do Cliente via token_url
DROP POLICY IF EXISTS "chamados_anon_select_por_token" ON public.chamados;
CREATE POLICY "chamados_anon_select_por_token"
ON public.chamados
FOR SELECT
TO anon
USING (token_url IS NOT NULL);

DROP POLICY IF EXISTS "chamados_anon_update_por_token" ON public.chamados;
CREATE POLICY "chamados_anon_update_por_token"
ON public.chamados
FOR UPDATE
TO anon
USING (token_url IS NOT NULL)
WITH CHECK (status IN ('aprovado_pendente', 'orcamento_enviado'));

-- 3. Atualizar função RPC de aprovação para também preencher pdf_url
CREATE OR REPLACE FUNCTION public.aprovar_orcamento_por_token(
    p_token UUID,
    p_razao_social TEXT DEFAULT NULL,
    p_cnpj TEXT DEFAULT NULL,
    p_inscricao_estadual TEXT DEFAULT NULL,
    p_endereco TEXT DEFAULT NULL,
    p_telefone TEXT DEFAULT NULL,
    p_cidade TEXT DEFAULT NULL,
    p_fabricante TEXT DEFAULT NULL,
    p_modelo_maquina TEXT DEFAULT NULL,
    p_numero_serie TEXT DEFAULT NULL,
    p_defeito_relatado TEXT DEFAULT NULL,
    p_responsavel_nome TEXT DEFAULT NULL,
    p_responsavel_cargo TEXT DEFAULT NULL,
    p_assinatura_url TEXT DEFAULT NULL,
    p_orcamento_pdf_url TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_updated INTEGER;
BEGIN
    UPDATE public.chamados
    SET
        status = 'aprovado_pendente',
        termos_aceitos = true,
        aceite_data = timezone('utc'::text, now()),
        razao_social = COALESCE(NULLIF(p_razao_social, ''), razao_social),
        cnpj = COALESCE(NULLIF(p_cnpj, ''), cnpj),
        inscricao_estadual = COALESCE(NULLIF(p_inscricao_estadual, ''), inscricao_estadual),
        endereco = COALESCE(NULLIF(p_endereco, ''), endereco),
        telefone = COALESCE(NULLIF(p_telefone, ''), telefone),
        cidade = COALESCE(NULLIF(p_cidade, ''), cidade),
        fabricante = COALESCE(NULLIF(p_fabricante, ''), fabricante),
        modelo_maquina = COALESCE(NULLIF(p_modelo_maquina, ''), modelo_maquina),
        numero_serie = COALESCE(NULLIF(p_numero_serie, ''), numero_serie),
        defeito_relatado = COALESCE(NULLIF(p_defeito_relatado, ''), defeito_relatado),
        responsavel_aceite_nome = COALESCE(NULLIF(p_responsavel_nome, ''), responsavel_aceite_nome),
        responsavel_aceite_cargo = COALESCE(NULLIF(p_responsavel_cargo, ''), responsavel_aceite_cargo),
        assinatura_url = COALESCE(NULLIF(p_assinatura_url, ''), assinatura_url),
        orcamento_pdf_url = COALESCE(NULLIF(p_orcamento_pdf_url, ''), orcamento_pdf_url),
        pdf_url = COALESCE(NULLIF(p_orcamento_pdf_url, ''), orcamento_pdf_url),
        updated_at = timezone('utc'::text, now())
    WHERE token_url = p_token;

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated > 0;
END;
$$;

GRANT EXECUTE ON FUNCTION public.aprovar_orcamento_por_token(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;
