---
name: backend-security
description: Use ao ESCREVER backend — API, endpoint, autenticação, sessão, upload, webhook, job, integração com terceiro, acesso a banco. Dispara em "criar API", "endpoint", "login", "autenticação", "autorização", "JWT", "sessão", "middleware", "upload", "webhook", "cron", "worker", "fila", "conexão com banco", "variável de ambiente", "CORS", "rate limit", "multi-tenant". Esta skill é para CONSTRUIR seguro. Para REVISAR código já escrito use security/appsec-audit; para desenhar antes do código use security/threat-modeling.
metadata:
  version: 1.0.0
---

# Backend seguro por construção

Segurança que entra no código enquanto ele é escrito, não numa auditoria depois. Auditoria acha o que sobrou; isto evita que sobre.

## Regra de ouro

**Toda decisão de acesso acontece no servidor, a cada requisição, contra a identidade da sessão — nunca contra um dado que o cliente mandou.**

Quase toda falha grave de backend é uma violação dessa frase. Leia de novo antes de escrever um endpoint.

## 1. Estrutura de um endpoint

Ordem fixa. Não pule etapa, não troque a ordem.

```
1. Autenticar    → quem é? (sessão/token válido, senão 401)
2. Autorizar     → pode fazer ISSO neste RECURSO? (senão 403/404)
3. Validar       → o payload tem a forma esperada? (schema, senão 422)
4. Executar      → a regra de negócio
5. Responder     → só o que este usuário pode ver
```

Erro clássico: validar antes de autorizar. Gasta processamento com quem não deveria estar ali e vaza estrutura interna pela mensagem de validação.

## 2. Autorização — onde mora o bug caro

**Todo acesso por identificador precisa provar propriedade.** Nunca:

```js
// ERRADO — qualquer usuário lê o pedido de qualquer outro
const pedido = await db.pedido.findUnique({ where: { id: req.params.id } });
```

Sempre:

```js
// CERTO — o dono entra na consulta, não numa checagem depois
const pedido = await db.pedido.findFirst({
  where: { id: req.params.id, usuarioId: req.session.userId },
});
if (!pedido) return res.status(404).end(); // 404, não 403 — não confirme que existe
```

Colocar o dono **na cláusula where** em vez de checar depois elimina a classe inteira de IDOR. Faça disso um padrão do projeto, não uma lembrança.

Multi-tenant: `tenantId` entra em toda consulta, sempre. Se o ORM suporta escopo global por tenant, ative — depender de disciplina humana em cada query falha.

### Mass assignment
```js
// ERRADO — cliente manda {"role":"admin"} e vira admin
await db.user.update({ where: { id }, data: req.body });

// CERTO — allowlist explícita
const { nome, email } = req.body;
await db.user.update({ where: { id }, data: { nome, email } });
```

## 3. Autenticação

- Senha: `argon2id` (preferido) ou `bcrypt` com custo ≥ 12. Nunca MD5/SHA puro.
- Comparação de token ou hash: função de tempo constante (`crypto.timingSafeEqual`). `===` em segredo vaza por timing.
- Reset de senha: token aleatório ≥ 32 bytes, hasheado no banco, uso único, expira em ≤ 1h, invalidado ao usar. A resposta é idêntica exista ou não o e-mail.
- Rate limit em login, reset e OTP — por conta **e** por IP. Sem isso, credential stuffing é trivial.
- Mensagem e tempo de resposta iguais para "usuário não existe" e "senha errada".

### Sessão
- Cookie: `HttpOnly`, `Secure`, `SameSite=Lax` (ou `Strict` se não houver fluxo cross-site).
- **Rotacione o identificador de sessão no login.** Sem isso: session fixation.
- Logout invalida no servidor. Apagar o cookie não é logout.
- JWT: algoritmo fixado no servidor (rejeite `alg: none` e a troca RS256→HS256), `exp` curto, segredo fora do código. JWT não se revoga — se precisa revogar, use sessão no servidor ou lista de revogação.

## 4. Entrada

- **Valide com schema** (zod, pydantic, joi) na borda. Tipo, formato, faixa, tamanho máximo. Rejeite campo desconhecido (`strict`).
- Banco: consulta parametrizada ou query builder. Concatenar string com input é falha mesmo "escapada".
- Comando de SO: evite. Se inevitável, argumentos como array, nunca string interpolada, nunca `shell: true`.
- Limite de tamanho de corpo, de arquivo e de profundidade de JSON — senão é DoS de graça.

## 5. Saída

- Serialize explicitamente. Nunca devolva o registro cru do banco: ele carrega `senhaHash`, `resetToken`, flags internas.
- Defina um DTO por endpoint. Campo novo no banco não deve aparecer na API sozinho.
- Erro para o cliente: mensagem genérica + id de correlação. Stack trace vai para o log, nunca para a resposta.

## 6. Segredos e configuração

- Zero segredo no repositório, inclusive no histórico do git. Se vazou, **rotacione** — remover o commit não basta, já foi clonado.
- Segredo em variável de ambiente ou cofre. `.env` no `.gitignore`.
- Valide a configuração no boot e **falhe rápido**: se falta `DATABASE_URL` ou `SESSION_SECRET`, o processo não sobe. Pior cenário é subir com um default inseguro.
- Nunca um valor padrão para segredo. `process.env.SECRET || "dev"` em produção é backdoor.

## 7. Headers e CORS

```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
Content-Security-Policy: default-src 'self'   (sem unsafe-inline/unsafe-eval)
Referrer-Policy: strict-origin-when-cross-origin
```

CORS: lista explícita de origens. **Nunca `*` junto com `credentials: true`** — e nunca refletir `Origin` do request sem validar contra a lista.

## 8. Upload

- Tipo por conteúdo (magic bytes), não por extensão nem `Content-Type`.
- Nome gerado pelo servidor (UUID). Nunca use o nome do cliente no caminho.
- Sirva de domínio separado ou com `Content-Disposition: attachment`.
- SVG servido inline no mesmo domínio = XSS. Trate como executável.

## 9. Falha e resiliência

- **Falhe fechado.** `catch` que segue o fluxo como se tivesse autorizado é falha crítica disfarçada.
- Timeout em toda chamada externa. Sem timeout, um terceiro lento derruba seu serviço.
- Circuit breaker em dependência instável.
- Rate limit global além do por-rota.

## 10. Log e observabilidade

- **Nunca logue** senha, token, cartão, CPF completo, corpo de requisição de autenticação. Redija na origem.
- **Sempre logue** evento de segurança: login falho, troca de senha, mudança de papel, acesso a dado sensível, falha de autorização.
- Id de correlação atravessando a requisição inteira.

## Checklist antes do merge

- [ ] Todo endpoint autentica e autoriza antes de validar
- [ ] Toda consulta por id inclui dono ou tenant na cláusula `where`
- [ ] Nenhum `update`/`create` recebe `req.body` inteiro
- [ ] Payload validado por schema estrito com limite de tamanho
- [ ] Resposta serializada por DTO, sem campo interno
- [ ] Nenhum segredo no código; config validada no boot
- [ ] CORS com origem explícita; headers de segurança presentes
- [ ] Rate limit em autenticação
- [ ] Erro não vaza stack; log não vaza segredo
- [ ] Timeout em toda chamada externa

## Antipadrões

1. **Checar permissão no front e confiar.** O cliente é do atacante.
2. **`findUnique({id})` seguido de `if (x.userId !== user.id)`** — funciona até alguém esquecer o `if`. Ponha o dono no `where`.
3. **Confiar em header do cliente** (`X-User-Id`, `X-Forwarded-For`) para decisão de acesso.
4. **Default inseguro em variável de ambiente.**
5. **Devolver o objeto do ORM direto.**
6. **Blocklist de input.** Sempre falta um caso; use allowlist.

## Relacionadas

Revisão do que já foi escrito: `security/appsec-audit`. Desenho antes do código: `security/threat-modeling`. Dado pessoal no fluxo: `compliance/lgpd-audit`. Integração e webhook: `dev/automations-integrations`. Padrões gerais de Node: `dev/nodejs-backend-patterns`.
