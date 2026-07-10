# Smarty Admin — Painel administrativo (⚠️ FORA DO ESCOPO DO BETA)

> **NÃO IMPLANTAR NESTA VERSÃO.** Este painel está incompleto e **não funciona
> de ponta a ponta**. Foi retirado do escopo do lançamento de testes.
> Não faça deploy público dele até que os itens abaixo sejam corrigidos.

## Por que está fora do beta

Problemas conhecidos que impedem o uso:

1. **Login nunca autentica.** `src/app/login/page.tsx` lê `data.tipoUsuario`,
   mas o backend retorna `user.tipo_usuario` (aninhado). O resultado é sempre
   "Acesso restrito a administradores.".
2. **Sem RBAC de admin no backend.** Mesmo que o login passasse, o middleware
   (`backend/lib/middleware/jwt_middleware.dart`) não tem regras para o perfil
   `admin`: rotas como `GET /cupons` e `GET /empresas/relatorio` exigem perfil
   `empresa` e retornariam 403.
3. **Mensagens de erro divergentes.** `src/lib/api.ts` lê `body.erro`, mas o
   backend envia `error` — erros aparecem genéricos.
4. **Sessão insegura.** Token em `localStorage` + cookie sem `HttpOnly`
   (`src/lib/auth.ts`), vulnerável a XSS. Precisa migrar para cookie `HttpOnly`
   antes de ir a público.

## Antes de reativar (pós-beta)

- [ ] Corrigir leitura do tipo de usuário e da chave de erro no cliente.
- [ ] Adicionar regras de ACL para o perfil `admin` no backend.
- [ ] Mover o token para cookie `HttpOnly`.
- [ ] Testar login → dashboard → cupons → relatório de ponta a ponta.

O código permanece no repositório de propósito, para retomada futura — apenas
não é buildado nem implantado no beta. O deploy do backend (`railway.toml`)
não inclui este diretório.
