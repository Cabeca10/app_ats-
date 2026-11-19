ALTER TABLE public.chamados REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'Exclusao orcamentos gerente'
  ) THEN
    CREATE POLICY "Exclusao orcamentos gerente"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
      bucket_id = 'orcamentos'
      AND EXISTS (
        SELECT 1
        FROM public.usuarios
        WHERE usuarios.id = (SELECT auth.uid())
          AND usuarios.role = ANY (ARRAY['gerente'::text, 'gerente_tecnico'::text])
      )
    );
  END IF;
END $$;
