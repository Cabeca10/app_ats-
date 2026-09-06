-- ==============================================================================
-- Migração: Fluxo de Orçamento e Assinatura Digital do Cliente (Pmach ATS)
-- Arquivo: supabase/migrations/20260906_orcamento_flow.sql
-- ==============================================================================

-- 1. Criação ou Atualização da Tabela 'chamados'
CREATE TABLE IF NOT EXISTS public.chamados (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero_ats VARCHAR(20) NOT NULL UNIQUE,
    razao_social VARCHAR(255) NOT NULL,
    cnpj VARCHAR(20),
    inscricao_estadual VARCHAR(30),
    telefone VARCHAR(30),
    cliente_email VARCHAR(255),
    endereco TEXT,
    cidade VARCHAR(100),
    
    -- Dados da Máquina / Equipamento
    fabricante VARCHAR(100),
    modelo_maquina VARCHAR(100),
    numero_serie VARCHAR(100),
    defeito_relatado TEXT,

    -- Token exclusivo para acesso público do cliente
    token_url UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,

    -- Status do Chamado
    status VARCHAR(30) DEFAULT 'novo' NOT NULL,

    -- Condições Comerciais do Orçamento
    taxa_horaria_comercial NUMERIC(10, 2) DEFAULT 306.00 NOT NULL,
    taxa_horaria_extra NUMERIC(10, 2) DEFAULT 459.00 NOT NULL,
    taxa_horaria_especial NUMERIC(10, 2) DEFAULT 612.00 NOT NULL,
    taxa_km NUMERIC(10, 2) DEFAULT 3.20 NOT NULL,
    km_estimado NUMERIC(10, 2) DEFAULT 0.00,
    hora_viagem_estimada NUMERIC(10, 2) DEFAULT 0.00,
    valor_estimado_total NUMERIC(10, 2) DEFAULT 0.00,

    -- Aceite e Assinatura do Cliente
    termos_aceitos BOOLEAN DEFAULT FALSE NOT NULL,
    aceite_data TIMESTAMPTZ,
    responsavel_aceite_nome VARCHAR(255),
    responsavel_aceite_cargo VARCHAR(100),
    assinatura_url TEXT,
    orcamento_pdf_url TEXT,

    -- Atribuição de Técnico
    tecnico_id UUID,
    tecnico_nome VARCHAR(255),

    -- Auditoria
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,

    CONSTRAINT status_check CHECK (
        status IN (
            'novo',
            'orcamento_enviado',
            'aprovado_pendente',
            'atribuido',
            'em_atendimento',
            'finalizado'
        )
    )
);

-- Índices para alta performance de consultas
CREATE INDEX IF NOT EXISTS idx_chamados_token_url ON public.chamados(token_url);
CREATE INDEX IF NOT EXISTS idx_chamados_status ON public.chamados(status);
CREATE INDEX IF NOT EXISTS idx_chamados_tecnico_id ON public.chamados(tecnico_id);

-- 2. Habilitação de Row Level Security (RLS)
ALTER TABLE public.chamados ENABLE ROW LEVEL SECURITY;

-- Política 1: Usuários Autenticados (Gerentes e Técnicos) têm acesso total
CREATE POLICY "Permissao total para usuarios autenticados" 
ON public.chamados
FOR ALL 
TO authenticated 
USING (true) 
WITH CHECK (true);

-- Política 2: Acesso Público de Leitura por token_url (Cliente acessa o orçamento)
CREATE POLICY "Leitura publica de orcamento por token" 
ON public.chamados
FOR SELECT 
TO anon 
USING (token_url IS NOT NULL);

-- Política 3: Acesso Público de Atualização por token_url (Cliente aprova e assina)
CREATE POLICY "Atualizacao publica de orcamento por token" 
ON public.chamados
FOR UPDATE 
TO anon 
USING (token_url IS NOT NULL)
WITH CHECK (
    -- Só permite aprovação mudando para 'aprovado_pendente'
    status IN ('aprovado_pendente', 'orcamento_enviado')
);

-- 3. Configuração do Storage Bucket para Orçamentos e Assinaturas
INSERT INTO storage.buckets (id, name, public)
VALUES ('orcamentos', 'orcamentos', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Políticas de Storage para o Bucket 'orcamentos'
CREATE POLICY "Leitura publica de orcamentos e assinaturas"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'orcamentos');

CREATE POLICY "Upload anonimo e autenticado em orcamentos"
ON storage.objects
FOR INSERT
TO public
WITH CHECK (bucket_id = 'orcamentos');
