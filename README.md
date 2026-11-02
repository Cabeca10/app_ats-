# Pmach ATS Digital

Sistema de Gestão de Ordens de Serviço (ATS) e Aprovação Eletrônica de Propostas Comerciais - Pmach Equipamentos e Peças Ltda.

---

## 🚀 Como Executar

### 1. Desenvolvimento Local
```bash
flutter run -d chrome
```

### 2. Homologação / Teste com Clientes via Celular (Túnel Temporário)
Quando precisar testar o envio de links de propostas pelo WhatsApp para clientes ou celulares externos:
```bash
# Terminal 1: Criar o túnel na mesma porta web
npx localtunnel --port 59176

# Terminal 2: Executar o Flutter apontando a URL base para o túnel
flutter run -d chrome --web-port=59176 --dart-define=APP_BASE_URL=https://pmach-teste.loca.lt
```

### 3. Build de Produção Web
```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://wdjoemplqzryixixosvh.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_HRi1dpoQRwuIucisv8BhZg_aFAWm97b \
  --dart-define=APP_BASE_URL=https://pmach-ats.web.app
```

Consulte o arquivo [`DEPLOY_WEB_GUIA.md`](DEPLOY_WEB_GUIA.md) para detalhes sobre Firebase Hosting, Cloudflare Pages e resolução de rotas SPA.
