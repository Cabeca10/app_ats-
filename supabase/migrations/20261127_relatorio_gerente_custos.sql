-- Migração: Fechamento de custos pelo técnico ("Relatório p/ Gerente")
-- e preservação de status Laranja -> Verde na tela do gerente.

ALTER TABLE public.chamados
  ADD COLUMN IF NOT EXISTS relatorio_gerente_enviado boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS relatorio_gerente_data timestamptz,
  ADD COLUMN IF NOT EXISTS custo_total_gerado numeric(12,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS relatorio_custos_json jsonb;

ALTER TABLE public.log_horas_custos
  ADD COLUMN IF NOT EXISTS hospedagem numeric(12,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS outros_custos numeric(12,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS observacoes text;
