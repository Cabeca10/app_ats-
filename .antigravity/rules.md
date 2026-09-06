# Diretrizes Estritas de Segurança (AppSec) - Repositório Público

## 1. Classificação do Repositório
- **ESTE REPOSITÓRIO NO GITHUB É PÚBLICO.**
- Qualquer dado, código ou comentário commitado estará imediatamente exposto na internet para acesso aberto.

## 2. Proibição de Hardcoded Secrets
É **terminantemente proibido** inserir ou manter no código-fonte qualquer uma das seguintes informações:
- Credenciais privadas e senhas (database passwords, master keys, senhas de teste ou produção).
- Chaves restritas de serviços (ex: Supabase `service_role_key`, Firebase Admin SDK, AWS Access/Secret Keys).
- Tokens de autenticação pessoal, Bearer tokens, tokens JWT reais.
- Chaves de criptografia, certificados privados (`.pem`, `.key`, `.p12`).
- Chaves de assinatura de aplicativos Android/iOS (`.keystore`, `.jks`, chaves de upload/release).
- URLs contendo credenciais embutidas (ex: `postgres://user:password@host/db`).

## 3. Gestão de Configurações e Variáveis de Ambiente
- Toda chave pública (como Supabase `anonKey`) ou configuração de ambiente deve ser carregada via variáveis de ambiente, argumentos de compilação (`--dart-define`) ou arquivos de ambiente devidamente ignorados pelo Git.
- Valores presentes no código de exemplo DEVEM ser sempre strings de placeholder inofensivas (ex: `https://your-supabase-url.supabase.co`, `your-supabase-anon-key`).

## 4. Inspeção Obrigatória Pré-Git
Antes de qualquer recomendação ou execução de comandos de versionamento (`git add`, `git commit`, `git push`):
1. **Auditoria Prévia**: Auditar detalhadamente a lista de arquivos alterados e não rastreados (`git status`).
2. **Inspeção de Diffs**: Verificar os diffs (`git diff` e `git diff --cached`) para garantir que nenhum segredo acidental foi inserido.
3. **Bloqueio de Arquivos Críticos**: Abortar imediatamente caso sejam detectados arquivos sensíveis como:
   - Arquivos de ambiente: `.env`, `.env.*`, `env.json`
   - Configurações de nuvem privadas: `google-services.json`, `GoogleService-Info.plist`, `service-account.json`
   - Chaves e certificados: `*.jks`, `*.keystore`, `*.pem`, `*.key`
4. Se qualquer arquivo desses estiver presente e não ignorado, ele deve ser adicionado ao `.gitignore` antes de prosseguir.
