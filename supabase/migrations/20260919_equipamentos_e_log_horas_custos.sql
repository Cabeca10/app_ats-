-- ==============================================================================
-- Migração: Tabelas de Equipamentos e Log de Horas/Custos com RLS Fail-Closed
-- Projeto: Pmach ATS Digital
-- Arquivo: supabase/migrations/20260919_equipamentos_e_log_horas_custos.sql
-- ==============================================================================

-- 0. Garantir estrutura da tabela 'usuarios' caso ainda não exista (para referência de perfis)
CREATE TABLE IF NOT EXISTS public.usuarios (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nome VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    perfil VARCHAR(50) NOT NULL DEFAULT 'tecnico', -- 'gerente' ou 'tecnico'
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT chk_perfil CHECK (perfil IN ('gerente', 'tecnico'))
);

ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'usuarios' AND policyname = 'Usuarios podem ler seus proprios dados'
    ) THEN
        CREATE POLICY "Usuarios podem ler seus proprios dados"
        ON public.usuarios
        FOR SELECT
        TO authenticated
        USING (id = auth.uid());
    END IF;
END $$;


-- ==============================================================================
-- 1. TABELA: equipamentos
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.equipamentos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    modelo VARCHAR(255) NOT NULL,
    fabricante VARCHAR(255) NOT NULL,
    numero_serie VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Índices de consulta
CREATE INDEX IF NOT EXISTS idx_equipamentos_numero_serie ON public.equipamentos(numero_serie);
CREATE INDEX IF NOT EXISTS idx_equipamentos_fabricante ON public.equipamentos(fabricante);

-- Habilitação ESTRITA de Row Level Security (RLS) - Princípio Fail-Closed
ALTER TABLE public.equipamentos ENABLE ROW LEVEL SECURITY;

-- Policy 1: SELECT (Leitura) restrita a usuários autenticados com perfis 'gerente' ou 'tecnico'
CREATE POLICY "Equipamentos: leitura permitida para gerente e tecnico autenticados"
ON public.equipamentos
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = auth.uid()
          AND (
            LOWER(u.perfil) IN ('gerente', 'tecnico')
          )
    )
    OR (auth.jwt() -> 'user_metadata' ->> 'role' IN ('gerente', 'tecnico'))
    OR (auth.jwt() -> 'app_metadata' ->> 'role' IN ('gerente', 'tecnico'))
);

-- Policy 2: INSERT/UPDATE/DELETE restrito apenas a 'gerente'
CREATE POLICY "Equipamentos: gerenciamento restrito a gerentes"
ON public.equipamentos
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


-- ==============================================================================
-- 2. TABELA: log_horas_custos
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.log_horas_custos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_chamado UUID NOT NULL REFERENCES public.chamados(id) ON DELETE CASCADE,
    data DATE NOT NULL DEFAULT CURRENT_DATE,
    hora_inicio TIME NOT NULL,
    hora_fim TIME NOT NULL,
    km_rodado NUMERIC(10, 2) DEFAULT 0.00 NOT NULL,
    pedagio NUMERIC(10, 2) DEFAULT 0.00 NOT NULL,
    refeicao NUMERIC(10, 2) DEFAULT 0.00 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Índices de Foreign Key e performance
CREATE INDEX IF NOT EXISTS idx_log_horas_custos_id_chamado ON public.log_horas_custos(id_chamado);
CREATE INDEX IF NOT EXISTS idx_log_horas_custos_data ON public.log_horas_custos(data);

-- Habilitação ESTRITA de Row Level Security (RLS) - Princípio Fail-Closed
ALTER TABLE public.log_horas_custos ENABLE ROW LEVEL SECURITY;

-- Prevenção de IDOR e BOLA:
-- O técnico só pode ler (SELECT) dados de chamados que ele mesmo atendeu (tecnico_id = auth.uid())
CREATE POLICY "Log Custos: Tecnico le apenas chamados que ele mesmo atendeu"
ON public.log_horas_custos
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = log_horas_custos.id_chamado
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

-- O técnico só pode inserir (INSERT) registros vinculados a chamados em que ele é o técnico responsável
CREATE POLICY "Log Custos: Tecnico insere apenas em chamados proprios"
ON public.log_horas_custos
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = log_horas_custos.id_chamado
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

-- O técnico só pode alterar (UPDATE) dados de chamados em que ele é o responsável
CREATE POLICY "Log Custos: Tecnico atualiza apenas chamados proprios"
ON public.log_horas_custos
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = log_horas_custos.id_chamado
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
        WHERE c.id = log_horas_custos.id_chamado
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

-- O técnico só pode excluir (DELETE) dados de chamados próprios (ou gerente)
CREATE POLICY "Log Custos: Tecnico exclui apenas registros de chamados proprios"
ON public.log_horas_custos
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = log_horas_custos.id_chamado
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
