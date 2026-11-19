-- ==============================================================================
-- Migração Consolidada e Idempotente: Schema Completo, RLS, RPCs, Storage e Realtime
-- Projeto: Pmach ATS Digital
-- Arquivo: supabase/migrations/20261118_fix_chamados_schema_rls_realtime.sql
-- ==============================================================================

-- 1. Garantir existência da tabela public.chamados e de todas as colunas usadas pelo Flutter
CREATE TABLE IF NOT EXISTS public.chamados (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero_ats VARCHAR(30),
    razao_social VARCHAR(255) NOT NULL DEFAULT '',
    token_url UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    status VARCHAR(40) DEFAULT 'novo' NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.chamados
    ADD COLUMN IF NOT EXISTS numero_ats VARCHAR(30),
    ADD COLUMN IF NOT EXISTS razao_social VARCHAR(255) DEFAULT '',
    ADD COLUMN IF NOT EXISTS contato TEXT,
    ADD COLUMN IF NOT EXISTS anotacao_envio TEXT,
    ADD COLUMN IF NOT EXISTS data_envio_link TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS cnpj VARCHAR(30),
    ADD COLUMN IF NOT EXISTS inscricao_estadual VARCHAR(50),
    ADD COLUMN IF NOT EXISTS telefone VARCHAR(50),
    ADD COLUMN IF NOT EXISTS fone TEXT,
    ADD COLUMN IF NOT EXISTS cliente_email VARCHAR(255),
    ADD COLUMN IF NOT EXISTS email_cliente VARCHAR(255),
    ADD COLUMN IF NOT EXISTS endereco TEXT,
    ADD COLUMN IF NOT EXISTS cidade VARCHAR(100),
    ADD COLUMN IF NOT EXISTS tipo_atendimento TEXT DEFAULT 'MANUTENÇÃO',
    ADD COLUMN IF NOT EXISTS fabricante VARCHAR(100),
    ADD COLUMN IF NOT EXISTS modelo_maquina VARCHAR(100),
    ADD COLUMN IF NOT EXISTS numero_serie VARCHAR(100),
    ADD COLUMN IF NOT EXISTS defeito_relatado TEXT,
    ADD COLUMN IF NOT EXISTS servico_executado TEXT,
    ADD COLUMN IF NOT EXISTS token_url UUID DEFAULT gen_random_uuid(),
    ADD COLUMN IF NOT EXISTS status VARCHAR(40) DEFAULT 'novo',
    ADD COLUMN IF NOT EXISTS taxa_horaria_comercial NUMERIC(10, 2) DEFAULT 306.00,
    ADD COLUMN IF NOT EXISTS taxa_horaria_extra NUMERIC(10, 2) DEFAULT 459.00,
    ADD COLUMN IF NOT EXISTS taxa_horaria_especial NUMERIC(10, 2) DEFAULT 612.00,
    ADD COLUMN IF NOT EXISTS taxa_km NUMERIC(10, 2) DEFAULT 3.20,
    ADD COLUMN IF NOT EXISTS km_estimado NUMERIC(10, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS hora_viagem_estimada NUMERIC(10, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS valor_estimado_total NUMERIC(10, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS termos_aceitos BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS aceite_data TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS responsavel_aceite_nome VARCHAR(255),
    ADD COLUMN IF NOT EXISTS responsavel_aceite_cargo VARCHAR(100),
    ADD COLUMN IF NOT EXISTS assinatura_url TEXT,
    ADD COLUMN IF NOT EXISTS orcamento_pdf_url TEXT,
    ADD COLUMN IF NOT EXISTS pdf_url TEXT,
    ADD COLUMN IF NOT EXISTS tecnico_id UUID,
    ADD COLUMN IF NOT EXISTS tecnico_nome VARCHAR(255),
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now());

-- Garantir largura suficiente de numero_ats e status e remover NOT NULL de colunas legadas
ALTER TABLE public.chamados
    ALTER COLUMN numero_ats TYPE VARCHAR(30),
    ALTER COLUMN numero_ats DROP NOT NULL,
    ALTER COLUMN status TYPE VARCHAR(40),
    ALTER COLUMN equipamento_modelo DROP NOT NULL,
    ALTER COLUMN equipamento_modelo SET DEFAULT '',
    ALTER COLUMN contato DROP NOT NULL,
    ALTER COLUMN contato SET DEFAULT '',
    ALTER COLUMN telefone DROP NOT NULL,
    ALTER COLUMN telefone SET DEFAULT '',
    ALTER COLUMN defeito_relatado DROP NOT NULL,
    ALTER COLUMN defeito_relatado SET DEFAULT '';

-- 2. Atualizar constraint status_check para aceitar todos os 7 status do fluxo
ALTER TABLE public.chamados DROP CONSTRAINT IF EXISTS status_check;
ALTER TABLE public.chamados
    ADD CONSTRAINT status_check CHECK (
        status IN (
            'novo',
            'orcamento_pendente_envio',
            'orcamento_enviado',
            'aprovado_pendente',
            'atribuido',
            'em_atendimento',
            'finalizado'
        )
    );

CREATE INDEX IF NOT EXISTS idx_chamados_token_url ON public.chamados(token_url);
CREATE INDEX IF NOT EXISTS idx_chamados_status ON public.chamados(status);
CREATE INDEX IF NOT EXISTS idx_chamados_tecnico_id ON public.chamados(tecnico_id);

-- 3. Garantir coluna telefone em public.usuarios
DO $$
BEGIN
    IF to_regclass('public.usuarios') IS NOT NULL THEN
        ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS telefone TEXT;
    END IF;
END $$;

-- 4. Sequência diária e Trigger para geração segura de numero_ats
CREATE TABLE IF NOT EXISTS public.ats_daily_sequences (
    dia DATE PRIMARY KEY,
    ultimo_sequencial INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.ats_daily_sequences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Sequences acessiveis por funcoes de sistema" ON public.ats_daily_sequences;
CREATE POLICY "Sequences acessiveis por funcoes de sistema"
ON public.ats_daily_sequences
FOR ALL
TO authenticated
USING ((select auth.uid()) IS NOT NULL)
WITH CHECK ((select auth.uid()) IS NOT NULL);

CREATE OR REPLACE FUNCTION public.gerar_numero_ats_sequencial()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_hoje DATE := CURRENT_DATE;
    v_seq INT;
    v_prefixo TEXT;
BEGIN
    IF NEW.numero_ats IS NOT NULL
       AND NEW.numero_ats ~ '^ATS-[0-9]{8}-[0-9]{3,}$' THEN
        RETURN NEW;
    END IF;

    INSERT INTO public.ats_daily_sequences (dia, ultimo_sequencial, updated_at)
    VALUES (v_hoje, 1, timezone('utc'::text, now()))
    ON CONFLICT (dia) DO UPDATE
    SET ultimo_sequencial = ats_daily_sequences.ultimo_sequencial + 1,
        updated_at = timezone('utc'::text, now())
    RETURNING ultimo_sequencial INTO v_seq;

    v_prefixo := 'ATS-' || to_char(v_hoje, 'YYYYMMDD') || '-';
    NEW.numero_ats := v_prefixo || lpad(v_seq::text, 3, '0');

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_gerar_numero_ats ON public.chamados;
CREATE TRIGGER trg_gerar_numero_ats
BEFORE INSERT ON public.chamados
FOR EACH ROW
EXECUTE FUNCTION public.gerar_numero_ats_sequencial();

-- 5. Garantir tabelas ats_dias_trabalho e ats_documentacoes
CREATE TABLE IF NOT EXISTS public.ats_dias_trabalho (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chamado_id UUID NOT NULL REFERENCES public.chamados(id) ON DELETE CASCADE,
    data DATE NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fim TIME,
    hora_almoco TIME DEFAULT '01:00',
    hora_viagem TIME DEFAULT '00:00',
    numero_tecnicos INTEGER NOT NULL DEFAULT 1,
    nomes_tecnicos TEXT NOT NULL,
    tecnicos_ids UUID[] DEFAULT '{}',
    horas_liquidas_minutos INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.ats_dias_trabalho
    ADD COLUMN IF NOT EXISTS tecnicos_ids UUID[] DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS horas_liquidas_minutos INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_ats_dias_trabalho_chamado_id ON public.ats_dias_trabalho(chamado_id);
CREATE INDEX IF NOT EXISTS idx_ats_dias_trabalho_tecnicos_ids ON public.ats_dias_trabalho USING GIN (tecnicos_ids);

ALTER TABLE public.ats_dias_trabalho ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Dias Trabalho: Leitura permitida para tecnico alocado e gerentes" ON public.ats_dias_trabalho;
DROP POLICY IF EXISTS "Dias Trabalho: Leitura permitida para tecnicos envolvidos e gerentes" ON public.ats_dias_trabalho;
DROP POLICY IF EXISTS "Dias Trabalho: Insercao restrita a tecnicos alocados ou gerentes" ON public.ats_dias_trabalho;
DROP POLICY IF EXISTS "Dias Trabalho: Atualizacao restrita a tecnicos alocados ou gerentes" ON public.ats_dias_trabalho;
DROP POLICY IF EXISTS "Dias Trabalho: Exclusao restrita a tecnicos alocados ou gerentes" ON public.ats_dias_trabalho;

CREATE POLICY "Dias Trabalho: Leitura permitida para tecnicos envolvidos e gerentes"
ON public.ats_dias_trabalho
FOR SELECT
TO authenticated
USING (
    ((select auth.uid()) = ANY(ats_dias_trabalho.tecnicos_ids))
    OR EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_dias_trabalho.chamado_id
          AND (c.tecnico_id = (select auth.uid()) OR c.id_tecnico = (select auth.uid()))
    )
    OR EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = (select auth.uid())
          AND LOWER(COALESCE(u.perfil, u.role, '')) IN ('gerente', 'gerente_tecnico')
    )
);

CREATE POLICY "Dias Trabalho: Insercao restrita a tecnicos alocados ou gerentes"
ON public.ats_dias_trabalho
FOR INSERT
TO authenticated
WITH CHECK (
    ((select auth.uid()) = ANY(ats_dias_trabalho.tecnicos_ids))
    OR EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_dias_trabalho.chamado_id
          AND (c.tecnico_id = (select auth.uid()) OR c.id_tecnico = (select auth.uid()))
    )
    OR EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = (select auth.uid())
          AND LOWER(COALESCE(u.perfil, u.role, '')) IN ('gerente', 'gerente_tecnico')
    )
);

CREATE POLICY "Dias Trabalho: Atualizacao restrita a tecnicos alocados ou gerentes"
ON public.ats_dias_trabalho
FOR UPDATE
TO authenticated
USING (
    ((select auth.uid()) = ANY(ats_dias_trabalho.tecnicos_ids))
    OR EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_dias_trabalho.chamado_id
          AND (c.tecnico_id = (select auth.uid()) OR c.id_tecnico = (select auth.uid()))
    )
    OR EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = (select auth.uid())
          AND LOWER(COALESCE(u.perfil, u.role, '')) IN ('gerente', 'gerente_tecnico')
    )
)
WITH CHECK (
    ((select auth.uid()) = ANY(ats_dias_trabalho.tecnicos_ids))
    OR EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_dias_trabalho.chamado_id
          AND (c.tecnico_id = (select auth.uid()) OR c.id_tecnico = (select auth.uid()))
    )
    OR EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = (select auth.uid())
          AND LOWER(COALESCE(u.perfil, u.role, '')) IN ('gerente', 'gerente_tecnico')
    )
);

CREATE POLICY "Dias Trabalho: Exclusao restrita a tecnicos alocados ou gerentes"
ON public.ats_dias_trabalho
FOR DELETE
TO authenticated
USING (
    ((select auth.uid()) = ANY(ats_dias_trabalho.tecnicos_ids))
    OR EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_dias_trabalho.chamado_id
          AND (c.tecnico_id = (select auth.uid()) OR c.id_tecnico = (select auth.uid()))
    )
    OR EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = (select auth.uid())
          AND LOWER(COALESCE(u.perfil, u.role, '')) IN ('gerente', 'gerente_tecnico')
    )
);

CREATE TABLE IF NOT EXISTS public.ats_documentacoes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chamado_id UUID NOT NULL REFERENCES public.chamados(id) ON DELETE CASCADE,
    anotacoes_campo TEXT DEFAULT '',
    fotos_urls TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT uq_ats_documentacoes_chamado UNIQUE (chamado_id)
);

CREATE INDEX IF NOT EXISTS idx_ats_documentacoes_chamado_id ON public.ats_documentacoes(chamado_id);
ALTER TABLE public.ats_documentacoes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ats_documentacoes_gerente_total" ON public.ats_documentacoes;
DROP POLICY IF EXISTS "ats_documentacoes_tecnico_select" ON public.ats_documentacoes;
DROP POLICY IF EXISTS "ats_documentacoes_tecnico_insert" ON public.ats_documentacoes;
DROP POLICY IF EXISTS "ats_documentacoes_tecnico_update" ON public.ats_documentacoes;

CREATE POLICY "ats_documentacoes_gerente_total"
ON public.ats_documentacoes
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = (select auth.uid())
          AND LOWER(COALESCE(u.perfil, u.role, '')) IN ('gerente', 'gerente_tecnico')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = (select auth.uid())
          AND LOWER(COALESCE(u.perfil, u.role, '')) IN ('gerente', 'gerente_tecnico')
    )
);

CREATE POLICY "ats_documentacoes_tecnico_select"
ON public.ats_documentacoes
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_documentacoes.chamado_id
          AND (c.tecnico_id = (select auth.uid()) OR c.id_tecnico = (select auth.uid()))
    )
);

CREATE POLICY "ats_documentacoes_tecnico_insert"
ON public.ats_documentacoes
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_documentacoes.chamado_id
          AND (c.tecnico_id = (select auth.uid()) OR c.id_tecnico = (select auth.uid()))
    )
);

CREATE POLICY "ats_documentacoes_tecnico_update"
ON public.ats_documentacoes
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_documentacoes.chamado_id
          AND (c.tecnico_id = (select auth.uid()) OR c.id_tecnico = (select auth.uid()))
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_documentacoes.chamado_id
          AND (c.tecnico_id = (select auth.uid()) OR c.id_tecnico = (select auth.uid()))
    )
);

-- 6. RLS na tabela public.chamados
ALTER TABLE public.chamados ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permissao total para usuarios autenticados" ON public.chamados;
DROP POLICY IF EXISTS "Leitura publica de orcamento por token" ON public.chamados;
DROP POLICY IF EXISTS "Atualizacao publica de orcamento por token" ON public.chamados;
DROP POLICY IF EXISTS "chamados_anon_select_por_token" ON public.chamados;
DROP POLICY IF EXISTS "chamados_anon_update_por_token" ON public.chamados;
DROP POLICY IF EXISTS "Clientes acessam e aprovam via token" ON public.chamados;
DROP POLICY IF EXISTS "Clientes acessam orcamento via token" ON public.chamados;
DROP POLICY IF EXISTS "Clientes aprovam orcamento via token" ON public.chamados;
DROP POLICY IF EXISTS "Gerente tem acesso total aos chamados" ON public.chamados;
DROP POLICY IF EXISTS "Gerentes criam e gerenciam chamados" ON public.chamados;
DROP POLICY IF EXISTS "Gerentes veem todos os chamados" ON public.chamados;
DROP POLICY IF EXISTS "Tecnicos veem seus chamados atribuidos" ON public.chamados;
DROP POLICY IF EXISTS "Chamados: Gestao total para Gerente" ON public.chamados;
DROP POLICY IF EXISTS "Chamados: Leitura para Tecnicos alocados ou envolvidos" ON public.chamados;
DROP POLICY IF EXISTS "Chamados: Atualizacao para Tecnicos alocados ou envolvidos" ON public.chamados;
DROP POLICY IF EXISTS "Chamados: Insercao para Tecnicos autenticados" ON public.chamados;

-- Política do Gerente (aceita perfis 'gerente' e 'gerente_tecnico')
CREATE POLICY "Chamados: Gestao total para Gerente"
ON public.chamados
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = (select auth.uid())
          AND LOWER(COALESCE(u.perfil, u.role, '')) IN ('gerente', 'gerente_tecnico')
    )
    OR (LOWER(COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', '')) IN ('gerente', 'gerente_tecnico'))
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = (select auth.uid())
          AND LOWER(COALESCE(u.perfil, u.role, '')) IN ('gerente', 'gerente_tecnico')
    )
    OR (LOWER(COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', '')) IN ('gerente', 'gerente_tecnico'))
);

CREATE POLICY "Chamados: Leitura para Tecnicos alocados ou envolvidos"
ON public.chamados
FOR SELECT
TO authenticated
USING (
    tecnico_id = (select auth.uid())
    OR id_tecnico = (select auth.uid())
    OR EXISTS (
        SELECT 1 FROM public.ats_dias_trabalho d
        WHERE d.chamado_id = chamados.id
          AND (select auth.uid()) = ANY(d.tecnicos_ids)
    )
);

CREATE POLICY "Chamados: Atualizacao para Tecnicos alocados ou envolvidos"
ON public.chamados
FOR UPDATE
TO authenticated
USING (
    tecnico_id = (select auth.uid())
    OR id_tecnico = (select auth.uid())
    OR EXISTS (
        SELECT 1 FROM public.ats_dias_trabalho d
        WHERE d.chamado_id = chamados.id
          AND (select auth.uid()) = ANY(d.tecnicos_ids)
    )
)
WITH CHECK (
    tecnico_id = (select auth.uid())
    OR id_tecnico = (select auth.uid())
    OR EXISTS (
        SELECT 1 FROM public.ats_dias_trabalho d
        WHERE d.chamado_id = chamados.id
          AND (select auth.uid()) = ANY(d.tecnicos_ids)
    )
);

CREATE POLICY "Chamados: Insercao para Tecnicos autenticados"
ON public.chamados
FOR INSERT
TO authenticated
WITH CHECK ((select auth.uid()) IS NOT NULL);

-- 7. RPCs Seguras para Acesso e Aprovação do Cliente via Token (p_token TEXT)
DROP FUNCTION IF EXISTS public.obter_orcamento_por_token(UUID);
DROP FUNCTION IF EXISTS public.obter_orcamento_por_token(TEXT);

CREATE OR REPLACE FUNCTION public.obter_orcamento_por_token(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_chamado JSONB;
BEGIN
    IF p_token IS NULL OR length(trim(p_token)) < 10 THEN
        RETURN NULL;
    END IF;

    SELECT to_jsonb(c)
    INTO v_chamado
    FROM public.chamados c
    WHERE c.token_url::text = TRIM(p_token)
    LIMIT 1;

    RETURN v_chamado;
END;
$$;

GRANT EXECUTE ON FUNCTION public.obter_orcamento_por_token(TEXT) TO anon, authenticated;

DROP FUNCTION IF EXISTS public.aprovar_orcamento_por_token(
    UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT
);
DROP FUNCTION IF EXISTS public.aprovar_orcamento_por_token(
    TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT
);

CREATE OR REPLACE FUNCTION public.aprovar_orcamento_por_token(
    p_token TEXT,
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
    IF p_token IS NULL OR length(trim(p_token)) < 10 THEN
        RETURN FALSE;
    END IF;

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
        pdf_url = COALESCE(NULLIF(p_orcamento_pdf_url, ''), pdf_url),
        updated_at = timezone('utc'::text, now())
    WHERE token_url::text = TRIM(p_token);

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated > 0;
END;
$$;

GRANT EXECUTE ON FUNCTION public.aprovar_orcamento_por_token(
    TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT
) TO anon, authenticated;

-- 8. Storage Bucket 'orcamentos' e Políticas (suportando upsert: true para anon e authenticated)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'orcamentos',
    'orcamentos',
    true,
    10485760,
    ARRAY['image/png', 'image/jpeg', 'application/pdf']::text[]
)
ON CONFLICT (id) DO UPDATE
SET
    public = true,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'application/pdf']::text[];

DROP POLICY IF EXISTS "Leitura publica de orcamentos e assinaturas" ON storage.objects;
DROP POLICY IF EXISTS "Upload anonimo e autenticado em orcamentos" ON storage.objects;
DROP POLICY IF EXISTS "Orcamentos: Leitura publica de assets" ON storage.objects;
DROP POLICY IF EXISTS "Orcamentos: Upload autenticado irrestrito" ON storage.objects;
DROP POLICY IF EXISTS "Orcamentos: Atualizacao autenticada irrestrita" ON storage.objects;
DROP POLICY IF EXISTS "Orcamentos: Upload anonimo restrito a assinaturas e pdfs" ON storage.objects;
DROP POLICY IF EXISTS "Orcamentos: Atualizacao anonima restrita a assinaturas e pdfs" ON storage.objects;

CREATE POLICY "Orcamentos: Leitura publica de assets"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'orcamentos');

CREATE POLICY "Orcamentos: Upload autenticado irrestrito"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'orcamentos');

CREATE POLICY "Orcamentos: Atualizacao autenticada irrestrita"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'orcamentos')
WITH CHECK (bucket_id = 'orcamentos');

CREATE POLICY "Orcamentos: Upload anonimo restrito a assinaturas e pdfs"
ON storage.objects
FOR INSERT
TO anon
WITH CHECK (
    bucket_id = 'orcamentos'
    AND (name LIKE 'assinaturas/%' OR name LIKE 'pdfs/%')
    AND (LOWER(storage.extension(name)) IN ('png', 'jpg', 'jpeg', 'pdf'))
);

CREATE POLICY "Orcamentos: Atualizacao anonima restrita a assinaturas e pdfs"
ON storage.objects
FOR UPDATE
TO anon
USING (
    bucket_id = 'orcamentos'
    AND (name LIKE 'assinaturas/%' OR name LIKE 'pdfs/%')
    AND (LOWER(storage.extension(name)) IN ('png', 'jpg', 'jpeg', 'pdf'))
)
WITH CHECK (
    bucket_id = 'orcamentos'
    AND (name LIKE 'assinaturas/%' OR name LIKE 'pdfs/%')
    AND (LOWER(storage.extension(name)) IN ('png', 'jpg', 'jpeg', 'pdf'))
);

-- 9. Ativar Realtime na tabela public.chamados
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
       AND NOT EXISTS (
           SELECT 1
           FROM pg_publication_tables
           WHERE pubname = 'supabase_realtime'
             AND schemaname = 'public'
             AND tablename = 'chamados'
       ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.chamados;
    END IF;
END $$;

-- 10. Recarregar schema do PostgREST
NOTIFY pgrst, 'reload schema';
