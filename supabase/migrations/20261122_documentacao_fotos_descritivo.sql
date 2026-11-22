ALTER TABLE public.ats_documentacoes
  ADD COLUMN IF NOT EXISTS itens_fotos JSONB NOT NULL DEFAULT '[]'::jsonb;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'Exclusao fotos documentacao equipe'
  ) THEN
    CREATE POLICY "Exclusao fotos documentacao equipe"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
      bucket_id = 'orcamentos'
      AND name LIKE 'documentacoes/%'
      AND EXISTS (
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
    );
  END IF;
END $$;

