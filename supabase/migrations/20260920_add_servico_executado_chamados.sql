-- ==============================================================================
-- Migração: Adiciona coluna servico_executado na tabela chamados
-- Projeto: Pmach ATS Digital
-- Arquivo: supabase/migrations/20260920_add_servico_executado_chamados.sql
-- ==============================================================================

ALTER TABLE public.chamados 
ADD COLUMN IF NOT EXISTS servico_executado TEXT;
