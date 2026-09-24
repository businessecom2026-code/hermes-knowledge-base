---
name: appsec-audit
description: Use ao revisar código, API, infraestrutura ou dependências em busca de falha de segurança. Dispara em "auditoria de segurança", "vulnerabilidade", "appsec", "pentest", "SQL injection", "XSS", "CSRF", "SSRF", "IDOR", "autenticação", "autorização", "secret vazado", "chave exposta", "CORS", "upload de arquivo", "deserialização", "dependência vulnerável", "OWASP". Também use antes de expor endpoint novo à internet, ao revisar login/sessão, e ao investigar acesso indevido.
metadata:
  version: 1.0.0
---

# Auditoria de segurança de aplicação

Revisão defensiva: encontrar e corrigir falha antes que vire incidente. Escopo é **código e configuração que você tem autorização para auditar**.

## Antes de começar

Confirme o escopo. Auditar sistema de terceiro sem autorização escrita não é auditoria — e a recusa aqui não é burocracia, é a diferença entre trabalho e crime. Se o alvo não é do usuário nem tem autorização documentada, pare e diga isso.

## Ordem de varredura

Vá do que causa perda total para o que causa perda parcial. Não comece por lint de segurança.

### 1. Autenticação
- Senha: hash com argon2id, scrypt ou bcrypt com custo atual. **Nunca** MD5, SHA1, SHA256 puro
- Comparação de token/hash em tempo constante — `==` em segredo vaza por timing
- Reset de senha: token de uso único, expiração curta, invalidado após uso, não revela se o e-mail existe
- Rate limit em login, reset e envio de OTP — por conta **e** por IP
- MFA: segredo TOTP guardado cifrado; código de backup hasheado
- Enumeração de usuário: mensagem e tempo de resposta idênticos para "usuário não existe" e "senha errada"

### 2. Sessão
- Cookie de sessão: `HttpOnly`, `Secure`, `SameSite=Lax` ou `Strict`
- Rotação do identificador de sessão no login (senão: session fixation)
- Logout invalida no servidor, não só apaga o cookie
- JWT: algoritmo fixado no servidor (rejeitar `alg: none` e troca RS256→HS256), `exp` verificado, segredo fora do código
- Sessão de longa duração com revogação possível

### 3. Autorização — onde mora o bug caro
- **IDOR**: todo acesso por ID verifica dono. `GET /pedido/123` precisa checar se 123 é do usuário logado. Este é o achado mais comum e mais explorado.
- Escalada horizontal (outro usuário) e vertical (admin) testadas separadamente
- Verificação no servidor, nunca só no front. Botão escondido não é controle de acesso.
- Endpoint de admin protegido por papel, não por rota obscura
- Mass assignment: `User.update(req.body)` deixa o cliente setar `role: admin`. Use allowlist de campos.

### 4. Injeção
- SQL: consulta parametrizada sempre. Concatenação com input é falha, mesmo "sanitizada"
- NoSQL: operador injetado (`{"$ne": null}` como senha)
- Comando de SO: evitar shell; se inevitável, passar argumentos como array, nunca string interpolada
- Template: template engine com input do usuário como *template* (SSTI), não como dado
- LDAP, XPath, header HTTP (CRLF injection)

### 5. XSS e saída
- Escape no ponto de renderização, por contexto (HTML, atributo, JS, URL, CSS)
- `dangerouslySetInnerHTML`, `v-html`, `innerHTML` — cada ocorrência justificada e com sanitização (DOMPurify)
- CSP restritiva sem `unsafe-inline`/`unsafe-eval`
- Upload de SVG servido no mesmo domínio = XSS

### 6. SSRF
- Fetch com URL do usuário: allowlist de destino, bloquear IP privado (`127.0.0.0/8`, `10/8`, `172.16/12`, `192.168/16`, `169.254.169.254`)
- Resolver DNS e validar o IP resolvido, não só a string (DNS rebinding)
- Redirect não seguido cegamente

### 7. Upload e arquivo
- Tipo validado por conteúdo (magic bytes), não por extensão nem `Content-Type`
- Nome de arquivo normalizado; bloquear `../` (path traversal)
- Arquivo servido de domínio separado ou com `Content-Disposition: attachment`
- Limite de tamanho aplicado no servidor

### 8. Segredo e configuração
- Nenhuma chave, senha ou token no repositório — inclusive no histórico do git
- `.env` no `.gitignore`; segredo em cofre ou variável de ambiente
- Chave de API com escopo mínimo e rotação possível
- Debug desligado em produção; stack trace não vai para o cliente
- CORS: origem explícita, nunca `*` junto com `credentials: true`
- Headers: `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `X-Frame-Options` ou `frame-ancestors`

### 9. Dependência
- `npm audit`, `pip-audit`, `cargo audit` ou equivalente
- Lockfile commitado
- Dependência abandonada ou com manutenção por conta única = risco de supply chain
- Instalador que roda script pós-install revisado antes de rodar

### 10. Log e monitoração
- Log não guarda senha, token, cartão, CPF completo
- Evento de segurança logado: login falho, troca de senha, escalada de papel, acesso a dado sensível
- Log protegido contra adulteração

## Formato do achado

```
[SEVERIDADE] classe · arquivo:linha
Falha: o que está errado
Exploração: entrada concreta -> efeito concreto (o que o atacante consegue)
Correção: mudança específica no código
```

Severidade pela combinação de impacto e facilidade:
- **CRÍTICO** — execução remota de código, bypass total de autenticação, exposição de base inteira, segredo de produção vazado
- **ALTO** — IDOR em dado sensível, SQLi, XSS armazenado, escalada para admin
- **MÉDIO** — XSS refletido, CSRF em ação relevante, rate limit ausente, header faltando
- **BAIXO** — divulgação de versão, cookie sem flag em contexto não sensível

**Regra:** só reporte o que você consegue descrever como cenário de exploração concreto. "Poderia ser inseguro" sem caminho de ataque é ruído, e ruído faz o time ignorar o relatório inteiro.

## Antipadrões

1. **Validação só no front.** O cliente é do atacante.
2. **Blocklist em vez de allowlist.** Sempre falta um caso.
3. **Criptografia caseira.** Use a biblioteca do runtime.
4. **`catch` que engole erro de segurança** e segue o fluxo como se tivesse autorizado.
5. **Segredo rotacionado no `.env` mas vivo no histórico do git.** Rotacionar exige revogar a chave antiga.
6. **Confiar em header do cliente** (`X-Forwarded-For`, `X-User-Id`) para decisão de acesso.

## Relacionadas

Para modelagem de ameaça antes de escrever o código, use `security/threat-modeling`. Para o recorte de dado pessoal e obrigação legal, use `compliance/lgpd-audit`.
