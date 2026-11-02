# Guia de Deploy Web e Túnel de Teste - Pmach ATS Digital

Este guia descreve como expor o sistema Pmach ATS para acesso externo de clientes (via celular, WhatsApp ou e-mail), tanto durante o desenvolvimento (via túnel temporário) quanto em produção definitiva (Firebase Hosting, Cloudflare ou domínio próprio).

---

## 1. Modo Homologação / Teste Externo (Sem Deploy Definitivo)

Quando o aplicativo estiver rodando localmente (ex: porta `59176` ou qualquer porta do Chrome), a URL `localhost` só funciona no próprio computador. Para testar o fluxo de aprovação e assinatura com um cliente real ou pelo seu próprio smartphone:

### Passo A: Criar o Túnel Temporário
Abra um terminal e execute uma das ferramentas abaixo:

#### Opção 1: localtunnel (Sem necessidade de cadastro)
```bash
# Substitua 59176 pela porta em que seu Flutter Web está rodando
npx localtunnel --port 59176
```
O terminal exibirá uma URL pública como:
```text
your url is: https://pmach-teste.loca.lt
```

#### Opção 2: ngrok
```bash
ngrok http 59176
```
O terminal fornecerá uma URL pública HTTPS (ex: `https://a1b2-c3d4.ngrok-free.app`).

---

### Passo B: Iniciar o Flutter com a URL do Túnel
Ao iniciar o Flutter, passe a variável `APP_BASE_URL` apontando para o seu túnel:

```bash
flutter run -d chrome --web-port=59176 --dart-define=APP_BASE_URL=https://pmach-teste.loca.lt
```

> **Resultado**: A partir desse momento, ao clicar em **[Copiar Link de Aprovação]** ou **[Enviar WhatsApp]**, os links gerados usarão a URL pública do túnel (ex: `https://pmach-teste.loca.lt/#/orcamento?token=...`), permitindo que qualquer pessoa pelo smartphone acesse, preencha seus dados fiscais, desenhe a assinatura e aprove a proposta em tempo real.

---

## 2. Modo Produção (Hospedagem Web Permanente)

Para publicar o sistema de forma definitiva no domínio oficial da empresa (ex: `https://ats.pmach.com.br` ou `https://pmach-ats.web.app`):

### Passo A: Compilar a Versão Web Release
Execute o comando com os parâmetros de produção:

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://wdjoemplqzryixixosvh.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_HRi1dpoQRwuIucisv8BhZg_aFAWm97b \
  --dart-define=APP_BASE_URL=https://ats.pmach.com.br
```

---

### Passo B: Publicação e Suporte a Rotas Diretas (Sem Erro 404)

Como o Flutter Web utiliza SPA (Single Page Application), ao acessar URLs diretas ou recarregar a página (ex: `/#/orcamento?token=...`), o servidor web precisa redirecionar qualquer rota interna para o `index.html`.

O projeto já conta com os arquivos pré-configurados:

1. **Firebase Hosting** (`firebase.json` na raiz):
   ```bash
   firebase deploy --only hosting
   ```
   *O arquivo `firebase.json` já contém a regra de rewrite `"source": "**", "destination": "/index.html"`.*

2. **Cloudflare Pages / Netlify** (`web/_redirects`):
   *O arquivo `web/_redirects` já contém `/* /index.html 200`, garantindo reescrita automática em servidores edge.*

3. **GitHub Pages / S3 Estático** (`web/404.html`):
   *O arquivo `web/404.html` redireciona automaticamente rotas estáticas mantendo query parameters e hash fragments.*

---

## 3. Resumo das Variáveis de Ambiente Suportadas

| Variável | Padrão | Descrição |
| :--- | :--- | :--- |
| `APP_BASE_URL` | `https://pmach-ats.web.app` | Domínio público base permanente de produção |
| `SUPABASE_URL` | `https://wdjoemplqzryixixosvh.supabase.co` | Endpoint do Supabase |
| `SUPABASE_ANON_KEY` | *(Chave pública de cliente)* | Chave pública anônima com RLS habilitado |
