-- ==============================================================================
-- Migration: Planilhas Mensais de Reembolso + Equipe Técnica em public.usuarios
-- Projeto: PMACH ATS Serviços
-- ==============================================================================

-- 1. Evolução da tabela public.usuarios para cadastro completo de técnicos
ALTER TABLE public.usuarios
  ADD COLUMN IF NOT EXISTS especialidade text,
  ADD COLUMN IF NOT EXISTS ativo boolean NOT NULL DEFAULT true;

-- 2. Popular public.usuarios a partir de auth.users existente (sem UUID hardcoded)
INSERT INTO public.usuarios (id, nome, email, role, perfil, ativo)
SELECT
  au.id,
  CASE
    WHEN lower(au.email) = 'alexandre.kansbock@pmach.com.br' THEN 'Alexandre Kansbock'
    WHEN lower(au.email) = 'ricardo.do.lima@gmail.com' THEN 'Ricardo Donizeti de Lima'
    ELSE COALESCE(
      NULLIF(trim(au.raw_user_meta_data ->> 'nome'), ''),
      initcap(replace(split_part(au.email, '@', 1), '.', ' '))
    )
  END AS nome,
  au.email,
  CASE
    WHEN lower(au.email) = 'alexandre.kansbock@pmach.com.br' THEN 'gerente'
    WHEN lower(au.email) = 'ricardo.do.lima@gmail.com' THEN 'gerente_tecnico'
    ELSE 'tecnico'
  END AS role,
  CASE
    WHEN lower(au.email) = 'alexandre.kansbock@pmach.com.br' THEN 'gerente'
    WHEN lower(au.email) = 'ricardo.do.lima@gmail.com' THEN 'gerente_tecnico'
    ELSE 'tecnico'
  END AS perfil,
  true AS ativo
FROM auth.users au
WHERE au.email IS NOT NULL
ON CONFLICT (id) DO NOTHING;

-- 3. Vincular chamados.tecnico_id retroativamente onde tecnico_id IS NULL e o nome bate
UPDATE public.chamados c
SET tecnico_id = u.id
FROM public.usuarios u
WHERE c.tecnico_id IS NULL
  AND c.tecnico_nome IS NOT NULL
  AND lower(trim(c.tecnico_nome)) = lower(trim(u.nome));

-- 4. Atualizar políticas RLS de public.chamados para incluir tecnico2_id
ALTER POLICY "Tecnicos atualizam chamados por tecnico_id" ON public.chamados
  USING (
    tecnico_id = (select auth.uid())
    OR id_tecnico = (select auth.uid())
    OR tecnico2_id = (select auth.uid())
  )
  WITH CHECK (
    tecnico_id = (select auth.uid())
    OR id_tecnico = (select auth.uid())
    OR tecnico2_id = (select auth.uid())
  );

ALTER POLICY "Tecnicos veem chamados por tecnico_id" ON public.chamados
  USING (
    tecnico_id = (select auth.uid())
    OR tecnico2_id = (select auth.uid())
  );

-- 5. Tabela principal das planilhas mensais de reembolso por técnico
CREATE TABLE IF NOT EXISTS public.planilhas_reembolso (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tecnico_id uuid NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  tecnico_nome text NOT NULL DEFAULT '',
  ano integer NOT NULL CHECK (ano >= 2020 AND ano <= 2100),
  mes integer NOT NULL CHECK (mes >= 1 AND mes <= 12),
  valor_km numeric(10,2) NOT NULL DEFAULT 1.50,
  valor_km_interno numeric(10,2) NOT NULL DEFAULT 0.74,
  valor_hora_tecnica numeric(10,2) NOT NULL DEFAULT 0.00,
  valor_hora_viagem numeric(10,2) NOT NULL DEFAULT 0.00,
  status text NOT NULL DEFAULT 'rascunho'
    CHECK (status IN ('rascunho', 'enviada', 'aprovada', 'ajuste_solicitado')),
  enviada_em timestamptz,
  aprovada_em timestamptz,
  observacao_gerente text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT planilhas_reembolso_tecnico_ano_mes_key UNIQUE (tecnico_id, ano, mes)
);

-- 6. Tabela de lançamentos diários da planilha mensal
CREATE TABLE IF NOT EXISTS public.planilhas_reembolso_itens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  planilha_id uuid NOT NULL REFERENCES public.planilhas_reembolso(id) ON DELETE CASCADE,
  tecnico_id uuid NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  chamado_id uuid REFERENCES public.chamados(id) ON DELETE SET NULL,
  dia date NOT NULL,
  cliente text NOT NULL DEFAULT '',
  numero_os text NOT NULL DEFAULT '',
  tipo_atendimento text NOT NULL DEFAULT 'Fora de garantia'
    CHECK (
      tipo_atendimento IN (
        'Fora de garantia',
        'Contrato',
        'Garantia Pmach',
        'Citzen',
        'Pmach Interno',
        'Visita Comercial'
      )
    ),
  horario_inicial text NOT NULL DEFAULT '',
  pausa_almoco text NOT NULL DEFAULT '01:00',
  horario_final text NOT NULL DEFAULT '',
  total_horas_trabalhadas_min integer NOT NULL DEFAULT 0,
  hora_viagem_min integer NOT NULL DEFAULT 0,
  km numeric(10,2) NOT NULL DEFAULT 0.00,
  pedagio numeric(10,2) NOT NULL DEFAULT 0.00,
  refeicao numeric(10,2) NOT NULL DEFAULT 0.00,
  pecas numeric(10,2) NOT NULL DEFAULT 0.00,
  outros numeric(10,2) NOT NULL DEFAULT 0.00,
  motivo_outros text NOT NULL DEFAULT '',
  ordem integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 7. Índices de performance
CREATE INDEX IF NOT EXISTS idx_planilhas_reembolso_tecnico_periodo
  ON public.planilhas_reembolso (tecnico_id, ano, mes);

CREATE INDEX IF NOT EXISTS idx_planilhas_reembolso_periodo
  ON public.planilhas_reembolso (ano, mes);

CREATE INDEX IF NOT EXISTS idx_planilhas_reembolso_itens_planilha
  ON public.planilhas_reembolso_itens (planilha_id, dia, ordem);

CREATE INDEX IF NOT EXISTS idx_planilhas_reembolso_itens_tecnico_dia
  ON public.planilhas_reembolso_itens (tecnico_id, dia);

CREATE INDEX IF NOT EXISTS idx_planilhas_reembolso_itens_chamado
  ON public.planilhas_reembolso_itens (chamado_id)
  WHERE chamado_id IS NOT NULL;

-- 8. Permissões e RLS em planilhas_reembolso e planilhas_reembolso_itens
ALTER TABLE public.planilhas_reembolso ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planilhas_reembolso_itens ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.planilhas_reembolso TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.planilhas_reembolso_itens TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'planilhas_reembolso'
      AND policyname = 'Planilhas Reembolso SELECT'
  ) THEN
    CREATE POLICY "Planilhas Reembolso SELECT"
      ON public.planilhas_reembolso
      FOR SELECT
      TO authenticated
      USING (
        tecnico_id = (select auth.uid())
        OR EXISTS (
          SELECT 1 FROM public.usuarios u
          WHERE u.id = (select auth.uid())
            AND lower(coalesce(u.role, u.perfil, '')) IN ('gerente', 'gerente_tecnico')
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'planilhas_reembolso'
      AND policyname = 'Planilhas Reembolso INSERT'
  ) THEN
    CREATE POLICY "Planilhas Reembolso INSERT"
      ON public.planilhas_reembolso
      FOR INSERT
      TO authenticated
      WITH CHECK (
        tecnico_id = (select auth.uid())
        OR EXISTS (
          SELECT 1 FROM public.usuarios u
          WHERE u.id = (select auth.uid())
            AND lower(coalesce(u.role, u.perfil, '')) IN ('gerente', 'gerente_tecnico')
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'planilhas_reembolso'
      AND policyname = 'Planilhas Reembolso UPDATE'
  ) THEN
    CREATE POLICY "Planilhas Reembolso UPDATE"
      ON public.planilhas_reembolso
      FOR UPDATE
      TO authenticated
      USING (
        tecnico_id = (select auth.uid())
        OR EXISTS (
          SELECT 1 FROM public.usuarios u
          WHERE u.id = (select auth.uid())
            AND lower(coalesce(u.role, u.perfil, '')) IN ('gerente', 'gerente_tecnico')
        )
      )
      WITH CHECK (
        tecnico_id = (select auth.uid())
        OR EXISTS (
          SELECT 1 FROM public.usuarios u
          WHERE u.id = (select auth.uid())
            AND lower(coalesce(u.role, u.perfil, '')) IN ('gerente', 'gerente_tecnico')
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'planilhas_reembolso'
      AND policyname = 'Planilhas Reembolso DELETE'
  ) THEN
    CREATE POLICY "Planilhas Reembolso DELETE"
      ON public.planilhas_reembolso
      FOR DELETE
      TO authenticated
      USING (
        tecnico_id = (select auth.uid())
        OR EXISTS (
          SELECT 1 FROM public.usuarios u
          WHERE u.id = (select auth.uid())
            AND lower(coalesce(u.role, u.perfil, '')) IN ('gerente', 'gerente_tecnico')
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'planilhas_reembolso_itens'
      AND policyname = 'Planilhas Itens SELECT'
  ) THEN
    CREATE POLICY "Planilhas Itens SELECT"
      ON public.planilhas_reembolso_itens
      FOR SELECT
      TO authenticated
      USING (
        tecnico_id = (select auth.uid())
        OR EXISTS (
          SELECT 1 FROM public.usuarios u
          WHERE u.id = (select auth.uid())
            AND lower(coalesce(u.role, u.perfil, '')) IN ('gerente', 'gerente_tecnico')
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'planilhas_reembolso_itens'
      AND policyname = 'Planilhas Itens INSERT'
  ) THEN
    CREATE POLICY "Planilhas Itens INSERT"
      ON public.planilhas_reembolso_itens
      FOR INSERT
      TO authenticated
      WITH CHECK (
        (
          tecnico_id = (select auth.uid())
          OR EXISTS (
            SELECT 1 FROM public.usuarios u
            WHERE u.id = (select auth.uid())
              AND lower(coalesce(u.role, u.perfil, '')) IN ('gerente', 'gerente_tecnico')
          )
        )
        AND EXISTS (
          SELECT 1 FROM public.planilhas_reembolso p
          WHERE p.id = planilha_id
            AND p.tecnico_id = planilhas_reembolso_itens.tecnico_id
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'planilhas_reembolso_itens'
      AND policyname = 'Planilhas Itens UPDATE'
  ) THEN
    CREATE POLICY "Planilhas Itens UPDATE"
      ON public.planilhas_reembolso_itens
      FOR UPDATE
      TO authenticated
      USING (
        tecnico_id = (select auth.uid())
        OR EXISTS (
          SELECT 1 FROM public.usuarios u
          WHERE u.id = (select auth.uid())
            AND lower(coalesce(u.role, u.perfil, '')) IN ('gerente', 'gerente_tecnico')
        )
      )
      WITH CHECK (
        (
          tecnico_id = (select auth.uid())
          OR EXISTS (
            SELECT 1 FROM public.usuarios u
            WHERE u.id = (select auth.uid())
              AND lower(coalesce(u.role, u.perfil, '')) IN ('gerente', 'gerente_tecnico')
          )
        )
        AND EXISTS (
          SELECT 1 FROM public.planilhas_reembolso p
          WHERE p.id = planilha_id
            AND p.tecnico_id = planilhas_reembolso_itens.tecnico_id
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'planilhas_reembolso_itens'
      AND policyname = 'Planilhas Itens DELETE'
  ) THEN
    CREATE POLICY "Planilhas Itens DELETE"
      ON public.planilhas_reembolso_itens
      FOR DELETE
      TO authenticated
      USING (
        tecnico_id = (select auth.uid())
        OR EXISTS (
          SELECT 1 FROM public.usuarios u
          WHERE u.id = (select auth.uid())
            AND lower(coalesce(u.role, u.perfil, '')) IN ('gerente', 'gerente_tecnico')
        )
      );
  END IF;
END $$;
