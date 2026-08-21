![Flutter](https://img.shields.io/badge/Flutter-3.6.1-02569B?logo=flutter&logoColor=white)




![Dart](https://img.shields.io/badge/Dart-3.6.1-0175C2?logo=dart&logoColor=white)




![License](https://img.shields.io/badge/license-MIT-green)




![Status](https://img.shields.io/badge/status-em%20testes-yellow)



# Smarty Entregas — Flutter

App mobile de delivery com três perfis: cliente, empresa e motoboy, todos no mesmo aplicativo.

> **Status:** projeto em fase de testes. O código pode ser buildado e explorado normalmente, mas o app depende de um backend próprio e de credenciais (Mapbox, Mercado Pago, Firebase) que não estão incluídas no repositório.

## Requisitos

- Flutter 3.6.1+
- Dart 3.6.1+
- Android SDK (API 21+)

## Configuração

1. Clone o repositório
2. Copie `.env.example` para `.env` e preencha as variáveis
3. Execute `flutter pub get`
4. Configure o `google-services.json` (Firebase)

## Rodando em modo debug

\`\`\`bash
flutter run
\`\`\`

Sem um backend próprio configurado, o app abre e navega normalmente, mas funcionalidades que dependem de API (login, pedidos, mapa, pagamento) não vão responder até você apontar `API_URL` para um backend seu.

## Variáveis de ambiente

Passadas no build do app via `--dart-define`:

| Variável | Descrição |
|----------|-----------|
| `API_URL` | URL base do backend (https em produção) |
| `MAPBOX_TOKEN` | Token do Mapbox (mapa e rotas) |
| `MP_PUBLIC_KEY` | Public Key do Mercado Pago (`APP_USR-...` em produção) |

Configuradas no backend via `.env` (nunca commitar — ver `.env.example`):

| Variável | Descrição |
|----------|-----------|
| `JWT_SECRET` | Segredo JWT |
| `DB_HOST/PORT/NAME/USER/PASS` | Conexão PostgreSQL |
| `GMAIL_USER` / `GMAIL_APP_PASSWORD` | SMTP para recuperação de senha |
| `MAPBOX_TOKEN` | Proxy de rotas no servidor |
| `FCM_PROJECT_ID` / `FCM_SERVICE_ACCOUNT_EMAIL` / `FCM_PRIVATE_KEY` | Push (FCM) |
| `MP_ACCESS_TOKEN` | Access Token do Mercado Pago |
| `GOOGLE_CLIENT_IDS` | Client IDs aceitos no login Google |
| `FACEBOOK_APP_ID` / `FACEBOOK_APP_SECRET` | Validação do login Facebook |

## Arquitetura

- **lib/core/** — utilitários, tema, carrinho, validadores
- **lib/data/** — sessão, cache, armazenamento local
- **lib/models/** — modelos de dados
- **lib/services/** — API, notificações, conectividade
- **lib/presentation/** — páginas e widgets

## Build de produção

Instruções de build de release (flags obrigatórias, checklist de publicação) estão fora deste README — ver `DEPLOY.md`.
