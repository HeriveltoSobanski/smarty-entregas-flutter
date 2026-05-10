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

# Release Android
flutter build apk --dart-define=API_URL=https://sua-api.com
```

## Variáveis de ambiente (`.env` — nunca commitar)

| Variável | Descrição |
|----------|-----------|
| `API_URL` | URL base do backend |
| `JWT_SECRET` | Segredo JWT (backend) |
| `GMAIL_USER` | Email para SMTP |
| `GMAIL_APP_PASSWORD` | Senha de app Gmail |
| `ORS_API_KEY` | OpenRouteService (rotas no mapa) |
| `FCM_PROJECT_ID` | Firebase Cloud Messaging |

## Arquitetura

- **lib/core/** — utilitários, tema, carrinho, validadores
- **lib/data/** — sessão, cache, armazenamento local
- **lib/models/** — modelos de dados
- **lib/services/** — API, notificações, conectividade
- **lib/presentation/** — páginas e widgets
