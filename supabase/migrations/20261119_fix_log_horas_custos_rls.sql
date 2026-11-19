ALTER POLICY "Log Custos: Tecnico le apenas chamados que ele mesmo atendeu"
ON public.log_horas_custos
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.chamados c
    WHERE c.id = log_horas_custos.id_chamado
      AND (
        c.id_tecnico = (SELECT auth.uid())
        OR c.tecnico_id = (SELECT auth.uid())
        OR c.tecnico2_id = (SELECT auth.uid())
        OR EXISTS (
          SELECT 1
          FROM public.usuarios u
          WHERE (
            u.id = (SELECT auth.uid())
            OR lower(u.email) = lower((SELECT auth.jwt() ->> 'email'))
          )
          AND (
            lower(coalesce(u.role, '')) IN ('gerente', 'gerente_tecnico', 'tecnico')
            OR lower(coalesce(u.perfil, '')) IN ('gerente', 'gerente_tecnico', 'tecnico')
          )
        )
      )
  )
);

ALTER POLICY "Log Custos: Tecnico insere apenas em chamados proprios"
ON public.log_horas_custos
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.chamados c
    WHERE c.id = log_horas_custos.id_chamado
      AND (
        c.id_tecnico = (SELECT auth.uid())
        OR c.tecnico_id = (SELECT auth.uid())
        OR c.tecnico2_id = (SELECT auth.uid())
        OR EXISTS (
          SELECT 1
          FROM public.usuarios u
          WHERE (
            u.id = (SELECT auth.uid())
            OR lower(u.email) = lower((SELECT auth.jwt() ->> 'email'))
          )
          AND (
            lower(coalesce(u.role, '')) IN ('gerente', 'gerente_tecnico', 'tecnico')
            OR lower(coalesce(u.perfil, '')) IN ('gerente', 'gerente_tecnico', 'tecnico')
          )
        )
      )
  )
);

ALTER POLICY "Log Custos: Tecnico atualiza apenas chamados proprios"
ON public.log_horas_custos
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.chamados c
    WHERE c.id = log_horas_custos.id_chamado
      AND (
        c.id_tecnico = (SELECT auth.uid())
        OR c.tecnico_id = (SELECT auth.uid())
        OR c.tecnico2_id = (SELECT auth.uid())
        OR EXISTS (
          SELECT 1
          FROM public.usuarios u
          WHERE (
            u.id = (SELECT auth.uid())
            OR lower(u.email) = lower((SELECT auth.jwt() ->> 'email'))
          )
          AND (
            lower(coalesce(u.role, '')) IN ('gerente', 'gerente_tecnico', 'tecnico')
            OR lower(coalesce(u.perfil, '')) IN ('gerente', 'gerente_tecnico', 'tecnico')
          )
        )
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.chamados c
    WHERE c.id = log_horas_custos.id_chamado
      AND (
        c.id_tecnico = (SELECT auth.uid())
        OR c.tecnico_id = (SELECT auth.uid())
        OR c.tecnico2_id = (SELECT auth.uid())
        OR EXISTS (
          SELECT 1
          FROM public.usuarios u
          WHERE (
            u.id = (SELECT auth.uid())
            OR lower(u.email) = lower((SELECT auth.jwt() ->> 'email'))
          )
          AND (
            lower(coalesce(u.role, '')) IN ('gerente', 'gerente_tecnico', 'tecnico')
            OR lower(coalesce(u.perfil, '')) IN ('gerente', 'gerente_tecnico', 'tecnico')
          )
        )
      )
  )
);

ALTER POLICY "Log Custos: Tecnico exclui apenas registros de chamados proprio"
ON public.log_horas_custos
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.chamados c
    WHERE c.id = log_horas_custos.id_chamado
      AND (
        c.id_tecnico = (SELECT auth.uid())
        OR c.tecnico_id = (SELECT auth.uid())
        OR c.tecnico2_id = (SELECT auth.uid())
        OR EXISTS (
          SELECT 1
          FROM public.usuarios u
          WHERE (
            u.id = (SELECT auth.uid())
            OR lower(u.email) = lower((SELECT auth.jwt() ->> 'email'))
          )
          AND (
            lower(coalesce(u.role, '')) IN ('gerente', 'gerente_tecnico', 'tecnico')
            OR lower(coalesce(u.perfil, '')) IN ('gerente', 'gerente_tecnico', 'tecnico')
          )
        )
      )
  )
);
