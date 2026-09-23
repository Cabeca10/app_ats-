-- ==============================================================================
-- Migração: Tabela de Documentações de Campo do Atendimento (Anotações e Fotos)
-- Projeto: Pmach ATS Digital
-- Arquivo: supabase/migrations/20260924_atendimento_documentacao.sql
-- ==============================================================================

-- 1. CRIAÇÃO DA TABELA: ats_documentacoes
CREATE TABLE IF NOT EXISTS public.ats_documentacoes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chamado_id UUID NOT NULL REFERENCES public.chamados(id) ON DELETE CASCADE,
    anotacoes_campo TEXT DEFAULT '',
    fotos_urls TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT uq_ats_documentacoes_chamado UNIQUE (chamado_id)
);

-- Índice de alta performance para busca por chamado
CREATE INDEX IF NOT EXISTS idx_ats_documentacoes_chamado_id ON public.ats_documentacoes(chamado_id);

-- 2. HABILITAÇÃO DE ROW LEVEL SECURITY (RLS)
ALTER TABLE public.ats_documentacoes ENABLE ROW LEVEL SECURITY;

-- Remove políticas legadas caso existam
DROP POLICY IF EXISTS "ats_documentacoes_gerente_total" ON public.ats_documentacoes;
DROP POLICY IF EXISTS "ats_documentacoes_tecnico_select" ON public.ats_documentacoes;
DROP POLICY IF EXISTS "ats_documentacoes_tecnico_insert" ON public.ats_documentacoes;
DROP POLICY IF EXISTS "ats_documentacoes_tecnico_update" ON public.ats_documentacoes;

-- 2.1. POLÍTICA DO GERENTE: Acesso total (SELECT, INSERT, UPDATE, DELETE)
CREATE POLICY "ats_documentacoes_gerente_total"
ON public.ats_documentacoes
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

-- 2.2. POLÍTICA DO TÉCNICO: SELECT
CREATE POLICY "ats_documentacoes_tecnico_select"
ON public.ats_documentacoes
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_documentacoes.chamado_id
          AND (
              c.tecnico_id = auth.uid()
              OR EXISTS (
                  SELECT 1 FROM public.ats_dias_trabalho d
                  WHERE d.chamado_id = c.id
                    AND auth.uid() = ANY(d.tecnicos_ids)
              )
          )
    )
);

-- 2.3. POLÍTICA DO TÉCNICO: INSERT
CREATE POLICY "ats_documentacoes_tecnico_insert"
ON public.ats_documentacoes
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_documentacoes.chamado_id
          AND (
              c.tecnico_id = auth.uid()
              OR EXISTS (
                  SELECT 1 FROM public.ats_dias_trabalho d
                  WHERE d.chamado_id = c.id
                    AND auth.uid() = ANY(d.tecnicos_ids)
              )
          )
    )
);

-- 2.4. POLÍTICA DO TÉCNICO: UPDATE
CREATE POLICY "ats_documentacoes_tecnico_update"
ON public.ats_documentacoes
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_documentacoes.chamado_id
          AND (
              c.tecnico_id = auth.uid()
              OR EXISTS (
                  SELECT 1 FROM public.ats_dias_trabalho d
                  WHERE d.chamado_id = c.id
                    AND auth.uid() = ANY(d.tecnicos_ids)
              )
          )
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_documentacoes.chamado_id
          AND (
              c.tecnico_id = auth.uid()
              OR EXISTS (
                  SELECT 1 FROM public.ats_dias_trabalho d
                  WHERE d.chamado_id = c.id
                    AND auth.uid() = ANY(d.tecnicos_ids)
              )
          )
    )
);
