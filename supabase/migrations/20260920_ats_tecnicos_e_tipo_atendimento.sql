-- ==============================================================================
-- Migração: Registro de Técnicos por Dia, Tipo de Atendimento e Relatório Mensal
-- Projeto: Pmach ATS Digital
-- Arquivo: supabase/migrations/20260920_ats_tecnicos_e_tipo_atendimento.sql
-- ==============================================================================

-- 1. ADICIONAR TIPO DE ATENDIMENTO NA TABELA 'chamados'
ALTER TABLE public.chamados 
ADD COLUMN IF NOT EXISTS tipo_atendimento TEXT NOT NULL DEFAULT 'MANUTENÇÃO';

-- Garantir constraint de integridade para os 4 tipos homologados
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_chamados_tipo_atendimento'
    ) THEN
        ALTER TABLE public.chamados 
        ADD CONSTRAINT chk_chamados_tipo_atendimento 
        CHECK (tipo_atendimento IN ('SERV. ENG.', 'MANUTENÇÃO', 'INSTALAÇÃO', 'GARANTIA'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_chamados_tipo_atendimento ON public.chamados(tipo_atendimento);


-- 2. VÍNCULO ESTRUTURADO DE TÉCNICOS E HORAS LÍQUIDAS EM 'ats_dias_trabalho'
ALTER TABLE public.ats_dias_trabalho 
ADD COLUMN IF NOT EXISTS tecnicos_ids UUID[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS horas_liquidas_minutos INTEGER NOT NULL DEFAULT 0;

-- Índice GIN para busca ultra rápida de chamados/dias por técnico
CREATE INDEX IF NOT EXISTS idx_ats_dias_trabalho_tecnicos_ids ON public.ats_dias_trabalho USING GIN (tecnicos_ids);


-- 3. PERMISSÕES RLS PARA LISTAGEM DE USUÁRIOS/TÉCNICOS
-- Permite que técnicos e gerentes autenticados listem os técnicos para alocação
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'usuarios' AND policyname = 'Usuarios autenticados podem listar equipe para alocacao'
    ) THEN
        CREATE POLICY "Usuarios autenticados podem listar equipe para alocacao"
        ON public.usuarios
        FOR SELECT
        TO authenticated
        USING (true);
    END IF;
END $$;


-- 4. POLÍTICAS RLS EXPANDIDAS EM 'ats_dias_trabalho'
-- Permite que qualquer técnico envolvido (responsável ou participante do dia) visualize e edite
DROP POLICY IF EXISTS "Dias Trabalho: Leitura permitida para tecnico alocado e gerentes" ON public.ats_dias_trabalho;
CREATE POLICY "Dias Trabalho: Leitura permitida para tecnicos envolvidos e gerentes"
ON public.ats_dias_trabalho
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_dias_trabalho.chamado_id
          AND (c.tecnico_id = auth.uid() OR auth.uid() = ANY(ats_dias_trabalho.tecnicos_ids))
    )
    OR (auth.uid() = ANY(ats_dias_trabalho.tecnicos_ids))
    OR EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = auth.uid()
          AND LOWER(u.perfil) = 'gerente'
    )
    OR (auth.jwt() -> 'user_metadata' ->> 'role' = 'gerente')
    OR (auth.jwt() -> 'app_metadata' ->> 'role' = 'gerente')
);

DROP POLICY IF EXISTS "Dias Trabalho: Insercao restrita a tecnicos alocados ou gerentes" ON public.ats_dias_trabalho;
CREATE POLICY "Dias Trabalho: Insercao restrita a tecnicos alocados ou gerentes"
ON public.ats_dias_trabalho
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_dias_trabalho.chamado_id
          AND (c.tecnico_id = auth.uid() OR auth.uid() = ANY(ats_dias_trabalho.tecnicos_ids))
    )
    OR (auth.uid() = ANY(ats_dias_trabalho.tecnicos_ids))
    OR EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = auth.uid()
          AND LOWER(u.perfil) = 'gerente'
    )
    OR (auth.jwt() -> 'user_metadata' ->> 'role' = 'gerente')
    OR (auth.jwt() -> 'app_metadata' ->> 'role' = 'gerente')
);

DROP POLICY IF EXISTS "Dias Trabalho: Atualizacao restrita a tecnicos alocados ou gerentes" ON public.ats_dias_trabalho;
CREATE POLICY "Dias Trabalho: Atualizacao restrita a tecnicos alocados ou gerentes"
ON public.ats_dias_trabalho
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_dias_trabalho.chamado_id
          AND (c.tecnico_id = auth.uid() OR auth.uid() = ANY(ats_dias_trabalho.tecnicos_ids))
    )
    OR (auth.uid() = ANY(ats_dias_trabalho.tecnicos_ids))
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
          AND (c.tecnico_id = auth.uid() OR auth.uid() = ANY(ats_dias_trabalho.tecnicos_ids))
    )
    OR (auth.uid() = ANY(ats_dias_trabalho.tecnicos_ids))
    OR EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = auth.uid()
          AND LOWER(u.perfil) = 'gerente'
    )
    OR (auth.jwt() -> 'user_metadata' ->> 'role' = 'gerente')
    OR (auth.jwt() -> 'app_metadata' ->> 'role' = 'gerente')
);

DROP POLICY IF EXISTS "Dias Trabalho: Exclusao restrita a tecnicos alocados ou gerentes" ON public.ats_dias_trabalho;
CREATE POLICY "Dias Trabalho: Exclusao restrita a tecnicos alocados ou gerentes"
ON public.ats_dias_trabalho
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.chamados c
        WHERE c.id = ats_dias_trabalho.chamado_id
          AND (c.tecnico_id = auth.uid() OR auth.uid() = ANY(ats_dias_trabalho.tecnicos_ids))
    )
    OR (auth.uid() = ANY(ats_dias_trabalho.tecnicos_ids))
    OR EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = auth.uid()
          AND LOWER(u.perfil) = 'gerente'
    )
    OR (auth.jwt() -> 'user_metadata' ->> 'role' = 'gerente')
    OR (auth.jwt() -> 'app_metadata' ->> 'role' = 'gerente')
);


-- 5. VIEW PARA RELATÓRIO MENSAL DE FECHAMENTO DE HORAS POR TÉCNICO
CREATE OR REPLACE VIEW public.v_relatorio_horas_tecnicos AS
SELECT 
    t_id AS tecnico_id,
    COALESCE(u.nome, 'Técnico Não Identificado') AS tecnico_nome,
    u.email AS tecnico_email,
    c.id AS chamado_id,
    c.numero_ats,
    c.razao_social,
    c.tipo_atendimento,
    d.id AS dia_id,
    d.data AS data_trabalho,
    EXTRACT(YEAR FROM d.data)::INTEGER AS ano,
    EXTRACT(MONTH FROM d.data)::INTEGER AS mes,
    d.hora_inicio,
    d.hora_fim,
    d.hora_almoco,
    d.hora_viagem,
    d.horas_liquidas_minutos,
    ROUND((d.horas_liquidas_minutos / 60.0), 2) AS horas_liquidas_decimal,
    -- Total acumulado do técnico no mês específico
    SUM(d.horas_liquidas_minutos) OVER (
        PARTITION BY t_id, EXTRACT(YEAR FROM d.data), EXTRACT(MONTH FROM d.data)
    ) AS total_mes_minutos,
    ROUND(
        SUM(d.horas_liquidas_minutos) OVER (
            PARTITION BY t_id, EXTRACT(YEAR FROM d.data), EXTRACT(MONTH FROM d.data)
        ) / 60.0, 
        2
    ) AS total_mes_horas_decimal
FROM public.ats_dias_trabalho d
JOIN public.chamados c ON c.id = d.chamado_id
CROSS JOIN LATERAL unnest(
    CASE 
        WHEN array_length(d.tecnicos_ids, 1) > 0 THEN d.tecnicos_ids 
        WHEN c.tecnico_id IS NOT NULL THEN ARRAY[c.tecnico_id]
        ELSE ARRAY[]::UUID[]
    END
) AS t_id
LEFT JOIN public.usuarios u ON u.id = t_id;

-- Concede privilégios de leitura na View para usuários autenticados
GRANT SELECT ON public.v_relatorio_horas_tecnicos TO authenticated;
