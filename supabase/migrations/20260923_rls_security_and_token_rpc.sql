-- ==============================================================================
-- Migração: Reforço de RLS, RPC Segura de Token e Proteção de Storage
-- Projeto: Pmach ATS Digital
-- Arquivo: supabase/migrations/20260923_rls_security_and_token_rpc.sql
-- ==============================================================================

-- 1. GARANTIR COLUNAS SUPORTADAS NA TABELA 'chamados'
ALTER TABLE public.chamados 
ADD COLUMN IF NOT EXISTS contato TEXT,
ADD COLUMN IF NOT EXISTS anotacao_envio TEXT,
ADD COLUMN IF NOT EXISTS data_envio_link TIMESTAMPTZ;

-- 2. RPC SEGURA PARA ACESSO DE CLIENTE VIA TOKEN (SECURITY DEFINER)
-- Retorna os dados do orçamento apenas quando o UUID exato do token for informado.
-- Impede que anônimos façam varreduras (dump) em massa da tabela de chamados.
CREATE OR REPLACE FUNCTION public.obter_orcamento_por_token(p_token UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_chamado JSONB;
BEGIN
    SELECT to_jsonb(c)
    INTO v_chamado
    FROM public.chamados c
    WHERE c.token_url = p_token
    LIMIT 1;

    RETURN v_chamado;
END;
$$;

GRANT EXECUTE ON FUNCTION public.obter_orcamento_por_token(UUID) TO anon, authenticated;

-- 3. RPC SEGURA PARA APROVAÇÃO E ASSINATURA DO CLIENTE POR TOKEN
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
        updated_at = timezone('utc'::text, now())
    WHERE token_url = p_token;

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated > 0;
END;
$$;

GRANT EXECUTE ON FUNCTION public.aprovar_orcamento_por_token(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;

-- 4. REFORMULAÇÃO DAS POLÍTICAS DE RLS NA TABELA 'chamados'
ALTER TABLE public.chamados ENABLE ROW LEVEL SECURITY;

-- 4.1. Remove as políticas permissivas legadas e inseguras
DROP POLICY IF EXISTS "Permissao total para usuarios autenticados" ON public.chamados;
DROP POLICY IF EXISTS "Leitura publica de orcamento por token" ON public.chamados;
DROP POLICY IF EXISTS "Atualizacao publica de orcamento por token" ON public.chamados;
DROP POLICY IF EXISTS "Chamados: Gestao total para Gerente" ON public.chamados;
DROP POLICY IF EXISTS "Chamados: Leitura para Tecnicos alocados ou envolvidos" ON public.chamados;
DROP POLICY IF EXISTS "Chamados: Atualizacao para Tecnicos alocados ou envolvidos" ON public.chamados;
DROP POLICY IF EXISTS "Chamados: Insercao para Tecnicos autenticados" ON public.chamados;

-- 4.2. POLÍTICA DO GERENTE: Acesso total (SELECT, INSERT, UPDATE, DELETE)
-- Gerente identificado pelo perfil na tabela 'usuarios' ou no metadata do JWT
CREATE POLICY "Chamados: Gestao total para Gerente"
ON public.chamados
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = auth.uid()
          AND LOWER(u.perfil) = 'gerente'
    )
    OR (auth.jwt() -> 'user_metadata' ->> 'role' = 'gerente')
    OR (auth.jwt() -> 'app_metadata' ->> 'role' = 'gerente')
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = auth.uid()
          AND LOWER(u.perfil) = 'gerente'
    )
    OR (auth.jwt() -> 'user_metadata' ->> 'role' = 'gerente')
    OR (auth.jwt() -> 'app_metadata' ->> 'role' = 'gerente')
);

-- 4.3. POLÍTICAS DO TÉCNICO:
-- Leitura apenas de chamados onde o técnico é o titular (tecnico_id = auth.uid()) 
-- OU onde está vinculado na lista de dias de trabalho (ats_dias_trabalho)
CREATE POLICY "Chamados: Leitura para Tecnicos alocados ou envolvidos"
ON public.chamados
FOR SELECT
TO authenticated
USING (
    tecnico_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.ats_dias_trabalho d
        WHERE d.chamado_id = chamados.id
          AND auth.uid() = ANY(d.tecnicos_ids)
    )
);

-- Atualização para Técnicos alocados (para finalizar ATS, preencher defeito e assinar)
CREATE POLICY "Chamados: Atualizacao para Tecnicos alocados ou envolvidos"
ON public.chamados
FOR UPDATE
TO authenticated
USING (
    tecnico_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.ats_dias_trabalho d
        WHERE d.chamado_id = chamados.id
          AND auth.uid() = ANY(d.tecnicos_ids)
    )
)
WITH CHECK (
    tecnico_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.ats_dias_trabalho d
        WHERE d.chamado_id = chamados.id
          AND auth.uid() = ANY(d.tecnicos_ids)
    )
);

-- Inserção permitida para técnicos autenticados caso abram chamados pelo app em campo
CREATE POLICY "Chamados: Insercao para Tecnicos autenticados"
ON public.chamados
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() IS NOT NULL
);

-- 5. CONFIGURAÇÃO E RESTRIÇÃO DO STORAGE BUCKET 'orcamentos'
UPDATE storage.buckets
SET 
    file_size_limit = 10485760, -- 10MB
    allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'application/pdf']::text[],
    public = true
WHERE id = 'orcamentos';

-- 5.1. Remove policies legadas do storage
DROP POLICY IF EXISTS "Leitura publica de orcamentos e assinaturas" ON storage.objects;
DROP POLICY IF EXISTS "Upload anonimo e autenticado em orcamentos" ON storage.objects;
DROP POLICY IF EXISTS "Orcamentos: Leitura publica de assets" ON storage.objects;
DROP POLICY IF EXISTS "Orcamentos: Upload autenticado irrestrito" ON storage.objects;
DROP POLICY IF EXISTS "Orcamentos: Upload anonimo restrito a assinaturas e pdfs" ON storage.objects;

-- 5.2. Leitura pública de documentos/assinaturas gerados
CREATE POLICY "Orcamentos: Leitura publica de assets"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'orcamentos');

-- 5.3. Upload para usuários autenticados (Técnicos e Gerentes)
CREATE POLICY "Orcamentos: Upload autenticado irrestrito"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'orcamentos');

-- 5.4. Upload para anônimos (Clientes assinando orçamento):
-- Restrito exclusivamente aos diretórios 'assinaturas/' e 'pdfs/' e extensões 'png', 'jpg', 'jpeg', 'pdf'
CREATE POLICY "Orcamentos: Upload anonimo restrito a assinaturas e pdfs"
ON storage.objects
FOR INSERT
TO anon
WITH CHECK (
    bucket_id = 'orcamentos'
    AND (
        name LIKE 'assinaturas/%' OR name LIKE 'pdfs/%'
    )
    AND (
        LOWER(storage.extension(name)) IN ('png', 'jpg', 'jpeg', 'pdf')
    )
);
