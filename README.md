# Smarty Entregas — Flutter

App mobile de delivery com três perfis: cliente, empresa e motoboy.

## Requisitos

- Flutter 3.6.1+
- Dart 3.6.1+
- Android SDK (API 21+)

## Configuração

1. Clone o repositório
2. Copie `.env.example` para `.env` e preencha as variáveis
3. Execute `flutter pub get`
4. Configure o `google-services.json` (Firebase)

## Build

```bash
# Debug
flutter run

# Release Android — TODAS as flags abaixo são obrigatórias para produção.
# O app se recusa a rodar em release sem API_URL https (ver api_service.dart)
# e a cobrar cartão com chave de teste do MP (ver mp_card_service.dart).
flutter build apk \
  --dart-define=API_URL=https://sua-api.com \
  --dart-define=MAPBOX_TOKEN=pk.seu_token_mapbox \
  --dart-define=MP_PUBLIC_KEY=APP_USR-sua_chave_producao
```

Checklist antes de gerar o APK de testes:

- [ ] `API_URL` aponta para o backend real via **https** (não localhost).
- [ ] `MP_PUBLIC_KEY` é a chave de **produção** (`APP_USR-...`), não `TEST-...`.
- [ ] Backend com `.env` de produção (inclui `GOOGLE_CLIENT_IDS`,
      `FACEBOOK_APP_ID/SECRET`, credenciais MP de produção).
- [ ] `google-services.json` de produção configurado.

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
