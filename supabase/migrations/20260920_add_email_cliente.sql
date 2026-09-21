-- ==============================================================================
-- Migração: Adicionar Coluna email_cliente na Tabela chamados
-- Projeto: Pmach ATS Digital
-- Arquivo: supabase/migrations/20260920_add_email_cliente.sql
-- ==============================================================================

-- 1. ADICIONAR COLUNA email_cliente
ALTER TABLE public.chamados 
ADD COLUMN IF NOT EXISTS email_cliente TEXT;

-- 2. SINCRONIZAR COM DADOS JÁ EXISTENTES DE cliente_email
UPDATE public.chamados 
SET email_cliente = cliente_email 
WHERE email_cliente IS NULL AND cliente_email IS NOT NULL;

-- 3. ÍNDICE PARA CONSULTAS DE CLIENTES
CREATE INDEX IF NOT EXISTS idx_chamados_email_cliente ON public.chamados(email_cliente);
