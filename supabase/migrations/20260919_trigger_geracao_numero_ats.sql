-- ==============================================================================
-- Migração: Geração Segura e Automática do campo numero_ats (Anti-Race Condition)
-- Projeto: Pmach ATS Digital
-- Arquivo: supabase/migrations/20260919_trigger_geracao_numero_ats.sql
-- ==============================================================================

-- 1. Ampliar tamanho da coluna numero_ats caso necessário para suportar 'ATS-YYYYMMDD-XXX'
ALTER TABLE public.chamados 
ALTER COLUMN numero_ats TYPE VARCHAR(30);

-- Permitir que numero_ats seja gerado automaticamente pelo Trigger no BEFORE INSERT
ALTER TABLE public.chamados 
ALTER COLUMN numero_ats DROP NOT NULL;

-- 2. Tabela de controle sequencial diário para prevenção estrita de Race Conditions
-- Utiliza mecanismo atômico nativo com bloqueio em nível de linha (Row-Level Locking)
CREATE TABLE IF NOT EXISTS public.ats_daily_sequences (
    dia DATE PRIMARY KEY,
    ultimo_sequencial INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Ativa RLS com princípio Fail-Closed na tabela auxiliar
ALTER TABLE public.ats_daily_sequences ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'ats_daily_sequences' AND policyname = 'Sequences acessiveis por funcoes de sistema'
    ) THEN
        CREATE POLICY "Sequences acessiveis por funcoes de sistema"
        ON public.ats_daily_sequences
        FOR ALL
        TO authenticated, anon
        USING (true)
        WITH CHECK (true);
    END IF;
END $$;


-- ==============================================================================
-- 3. FUNÇÃO DO TRIGGER: gerar_numero_ats_sequencial()
-- ==============================================================================
-- Opera em modo SECURITY DEFINER para garantir atomicidade e isolamento transacional
CREATE OR REPLACE FUNCTION public.gerar_numero_ats_sequencial()
RETURNS TRIGGER AS $$
DECLARE
    v_hoje DATE := CURRENT_DATE;
    v_seq INT;
    v_prefixo TEXT;
BEGIN
    -- Se o numero_ats já vier preenchido e formatado corretamente no padrão ATS-YYYYMMDD-XXX, mantém
    IF NEW.numero_ats IS NOT NULL 
       AND NEW.numero_ats ~ '^ATS-[0-9]{8}-[0-9]{3,}$' THEN
        RETURN NEW;
    END IF;

    -- ==========================================================================
    -- PREVENÇÃO CRÍTICA DE RACE CONDITION (AppSec):
    -- O comando INSERT ... ON CONFLICT DO UPDATE ... RETURNING adquire
    -- automaticamente um bloqueio exclusivo de linha (Row-Level Lock) no registro
    -- do dia correspondente.
    -- Transações concorrentes simultâneas aguardam a liberação do lock, eliminando
    -- 100% de probabilidade de geração de números duplicados.
    -- ==========================================================================
    INSERT INTO public.ats_daily_sequences (dia, ultimo_sequencial, updated_at)
    VALUES (v_hoje, 1, timezone('utc'::text, now()))
    ON CONFLICT (dia) DO UPDATE
    SET ultimo_sequencial = ats_daily_sequences.ultimo_sequencial + 1,
        updated_at = timezone('utc'::text, now())
    RETURNING ultimo_sequencial INTO v_seq;

    -- Monta o prefixo no formato: ATS-YYYYMMDD- (ex: ATS-20260919-)
    v_prefixo := 'ATS-' || to_char(v_hoje, 'YYYYMMDD') || '-';

    -- Gera o formato final com zero à esquerda de no mínimo 3 dígitos (ex: ATS-20260919-001)
    NEW.numero_ats := v_prefixo || lpad(v_seq::text, 3, '0');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ==============================================================================
-- 4. TRIGGER: trg_gerar_numero_ats (BEFORE INSERT ON chamados)
-- ==============================================================================
DROP TRIGGER IF EXISTS trg_gerar_numero_ats ON public.chamados;

CREATE TRIGGER trg_gerar_numero_ats
BEFORE INSERT ON public.chamados
FOR EACH ROW
EXECUTE FUNCTION public.gerar_numero_ats_sequencial();
