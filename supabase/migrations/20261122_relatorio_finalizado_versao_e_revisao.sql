ALTER TABLE public.chamados
  ADD COLUMN IF NOT EXISTS relatorio_pdf_url TEXT,
  ADD COLUMN IF NOT EXISTS relatorio_versao INTEGER NOT NULL DEFAULT 0;

-- Backfill chamados já finalizados onde orcamento_pdf_url foi sobrescrito pelo relatório final
UPDATE public.chamados
SET
  relatorio_pdf_url = COALESCE(relatorio_pdf_url, orcamento_pdf_url),
  relatorio_versao = CASE WHEN COALESCE(relatorio_versao, 0) = 0 THEN 1 ELSE relatorio_versao END,
  orcamento_pdf_url = COALESCE(pdf_url, orcamento_pdf_url)
WHERE status = 'finalizado'
  AND orcamento_pdf_url LIKE '%/relatorios_ats/%';

UPDATE public.chamados
SET relatorio_versao = 1
WHERE status = 'finalizado'
  AND COALESCE(relatorio_versao, 0) = 0;

-- Permite que técnicos e gerentes autenticados apaguem a versão anterior do relatório/assinatura ATS ao revisar
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'Exclusao relatorios antigos equipe'
  ) THEN
    CREATE POLICY "Exclusao relatorios antigos equipe"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
      bucket_id = 'orcamentos'
      AND (name LIKE 'relatorios_ats/%' OR name LIKE 'assinaturas/ats_%')
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

