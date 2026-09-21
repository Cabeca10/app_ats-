-- ==============================================================================
-- Migração: Tabela de Dias de Trabalho e Apontamento de Horas no ATS
-- Projeto: Pmach ATS Digital
-- Arquivo: supabase/migrations/20260920_ats_dias_trabalho.sql
-- ==============================================================================

-- 1. CRIAÇÃO DA TABELA: ats_dias_trabalho
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
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Índices de consulta e integridade relacional
CREATE INDEX IF NOT EXISTS idx_ats_dias_trabalho_chamado_id ON public.ats_dias_trabalho(chamado_id);
CREATE INDEX IF NOT EXISTS idx_ats_dias_trabalho_data ON public.ats_dias_trabalho(data);

-- Habilitação ESTRITA de Row Level Security (RLS) - Princípio Fail-Closed
ALTER TABLE public.ats_dias_trabalho ENABLE ROW LEVEL SECURITY;

-- Policy 1: SELECT (Leitura) restrita ao técnico alocado ou usuários gerentes
CREATE POLICY "Dias Trabalho: Leitura permitida para tecnico alocado e gerentes"
ON public.ats_dias_trabalho
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_dias_trabalho.chamado_id
          AND c.tecnico_id = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = auth.uid()
          AND LOWER(u.perfil) = 'gerente'
    )
    OR (auth.jwt() -> 'user_metadata' ->> 'role' = 'gerente')
    OR (auth.jwt() -> 'app_metadata' ->> 'role' = 'gerente')
);

-- Policy 2: INSERT restrito ao técnico alocado no chamado ou gerentes
CREATE POLICY "Dias Trabalho: Insercao restrita a tecnicos alocados ou gerentes"
ON public.ats_dias_trabalho
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_dias_trabalho.chamado_id
          AND c.tecnico_id = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = auth.uid()
          AND LOWER(u.perfil) = 'gerente'
    )
    OR (auth.jwt() -> 'user_metadata' ->> 'role' = 'gerente')
    OR (auth.jwt() -> 'app_metadata' ->> 'role' = 'gerente')
);

-- Policy 3: UPDATE restrito ao técnico alocado ou gerentes
CREATE POLICY "Dias Trabalho: Atualizacao restrita a tecnicos alocados ou gerentes"
ON public.ats_dias_trabalho
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_dias_trabalho.chamado_id
          AND c.tecnico_id = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = auth.uid()
          AND LOWER(u.perfil) = 'gerente'
    )
    OR (auth.jwt() -> 'user_metadata' ->> 'role' = 'gerente')
    OR (auth.jwt() -> 'app_metadata' ->> 'role' = 'gerente')
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_dias_trabalho.chamado_id
          AND c.tecnico_id = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = auth.uid()
          AND LOWER(u.perfil) = 'gerente'
    )
    OR (auth.jwt() -> 'user_metadata' ->> 'role' = 'gerente')
    OR (auth.jwt() -> 'app_metadata' ->> 'role' = 'gerente')
);

-- Policy 4: DELETE restrito ao técnico alocado ou gerentes
CREATE POLICY "Dias Trabalho: Exclusao restrita a tecnicos alocados ou gerentes"
ON public.ats_dias_trabalho
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_dias_trabalho.chamado_id
          AND c.tecnico_id = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = auth.uid()
          AND LOWER(u.perfil) = 'gerente'
    )
    OR (auth.jwt() -> 'user_metadata' ->> 'role' = 'gerente')
    OR (auth.jwt() -> 'app_metadata' ->> 'role' = 'gerente')
);
