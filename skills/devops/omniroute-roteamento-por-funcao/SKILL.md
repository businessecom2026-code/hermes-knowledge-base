---
name: omniroute-roteamento-por-funcao
description: Use ao configurar combos e fallback no OmniRoute.
---

# Roteamento por função no OmniRoute

Use esta skill ao configurar combos, roteamento, fallback ou barateamento de
tokens no OmniRoute: quando um modelo só (ex. Claude) domina o consumo, ao mapear
funções para modelos variados, ou ao escolher estratégia de combo.

O sintoma clássico: "está usando só claude claude claude". A causa quase nunca é
falta de fallback — é que todos os combos são **o mesmo combo com nomes
diferentes**, em `priority`, com o mesmo líder caro.

## Diagnostique com dados antes de mexer

O banco é `~/.omniroute/storage.sqlite` (abra `mode=ro`). Duas consultas bastam:

```sql
-- quem realmente consome
select provider, model, count(*) n, sum(tokens_in) tin, sum(tokens_cache_read) tcr
from call_logs where timestamp > datetime('now','-7 days')
group by provider, model order by n desc limit 20;

-- o fallback chega a rodar?
select combo_name, provider||'/'||model m, count(*) n
from call_logs where timestamp > datetime('now','-7 days') and combo_name is not null
group by combo_name, m order by combo_name, n desc;
```

Se o líder tem 90%+ das chamadas do combo, o fallback nunca roda: `priority` só
cai para o próximo quando o anterior **falha**, e um modelo caro não falha — ele
só custa caro.

## Regra do cache: varie por FUNÇÃO, nunca por request

Antes de distribuir, cheque a razão `tokens_cache_read / tokens_in`. Quando é
alta (ex. 98,9%), trocar de modelo dentro de uma mesma sessão **quebra o prompt
cache** e faz a próxima chamada pagar input cheio — distribuir por request
ENCARECE. A variação correta é por função: cada função fixa no seu modelo, com
`cache-optimized` nas de sessão longa (dev, orchestrator).

## As três armadilhas (todas custam retrabalho)

**1. `cost-optimized` promove o modelo PAGO.** `sortModelsByCost()`
(`open-sse/services/combo/targetSorters.ts`) atribui custo `Infinity` a todo
modelo sem pricing cadastrado e o joga para o FIM da fila. Modelos free do
OpenRouter não têm tabela de preço → são despriorizados e o pago (que tem preço)
lidera. Para cadeia liderada por free, use **`priority`**, que respeita a ordem
literal.

**2. `/v1/models` lista modelos fantasma.** O endpoint devolve o catálogo
completo, mas o catálogo ATIVO recusa boa parte com `HTTP 400 model_not_found`.
Num teste real, 16 de 27 candidatos não existiam. **Sempre valide com chamada
real + tool-calling antes de colocar na cadeia.**

**3. `429` e `400` mascarados no Codex.** `quota_snapshots` pode indicar
100% restante enquanto a chamada real retorna 429 (rate limit de curto prazo da OpenAI)
ou 400 `model_not_found` (modelos que a API tira do ar silenciosamente sem avisar, como `gpt-5.6-sol-high`).
Teste real manda; snapshot é indicativo. Se o Codex não roda, teste qual `gpt-5.6-terra-X` ou `luna-X` responde.

## Estratégias que valem (das 20 implementadas)

| Estratégia | Quando |
|---|---|
| `cache-optimized` | produção de sessão longa; preserva prompt cache |
| `headroom` | manda para a conta com MAIS cota livre em vez de fritar uma até o 429 |
| `priority` | ordem literal — decisão deliberada de qualidade, ou líder free |
| `reset-aware` / `reset-window` | respeita janela de reset do plano |
| `auto` | scoring por health/cota/custo/velocidade/task-fit; variantes `auto/coding`, `auto/fast`, `auto/cheap` |

Evite `cost-optimized` salvo se todo modelo da cadeia tiver pricing cadastrado.

## Como escrever a configuração

A API de gestão NÃO aceita a chave de inferência `sk-…` (403
`Invalid management token`) a menos que tenha escopo `manage`. Em loopback, use o
CLI machine-token:

```js
import { getCliToken } from "file:///<npm-global>/node_modules/omniroute/bin/cli/utils/cliToken.mjs";
const token = await getCliToken();
// header: "x-omniroute-cli-token": token
// PUT /api/combos/<id> com { name, strategy, enabled, models, config }
```

Cada item de `models` precisa de `{ id, kind:"model", model, providerId, weight }`,
onde `providerId` é o prefixo antes da primeira `/`.

**Nunca imprima o token no shell.** Faça a chamada dentro do próprio script Node.

## Ordem de trabalho obrigatória

1. Diagnostique com SQL (não confie na intuição sobre quem consome).
2. Cheque a razão de cache antes de decidir distribuir.
3. Teste os candidatos com chamada real + tool-calling.
4. Faça backup (`GET /api/combos` → arquivo) antes de qualquer PUT.
5. Rode em dry-run, depois aplique.
6. **Verifique com chamada real por combo** e confira o campo `model` da resposta —
   é o único jeito de saber quem realmente atendeu.
7. Confirme nos `call_logs` se algum alvo deu 400/429 e caiu para o fallback.

O passo 6 é o que pega o erro do `cost-optimized`: a configuração grava com
sucesso e mesmo assim o modelo errado atende.

## Separar conta pessoal de conta da empresa

Quando um provedor é conta da empresa (Claude/`cc/*`, Antigravity) e outro é
conta pessoal (Codex/`cx/*`), não basta "evitar" o caro: crie uma família de
combos isolada e ponha uma **guarda dura no script** que lança erro se qualquer
modelo proibido entrar na cadeia. Sem isso, um copy-paste futuro vaza a conta.

O vazamento silencioso mora no `auxiliary.compression.model` do profile: ele
normalmente aponta para `combo/fast`, que termina em `claude-haiku`. Um combo
pessoal sem combo de compressão próprio ainda queima a conta da empresa a cada
compactação de contexto.

Verificação que fecha a questão — `call_logs`, não a resposta da API:

```sql
select combo_name, provider||'/'||model, count(*) from call_logs
where timestamp > datetime('now','-20 minutes') and combo_name like '<prefixo>%'
group by 1,2;
```

## Criar combo novo (POST), não só editar

`/api/combos` aceita `POST` com o mesmo payload do `PUT`
(`{name, strategy, enabled, models, config}`) e devolve 200/201. O script deve
tratar os dois casos: `PUT /api/combos/<id>` se o nome já existe, `POST` se não.

## Comando de atalho por família de combo

No Windows são DOIS arquivos em `~/.local/bin`, porque `.bat` não é executável
pelo bash do MSYS e o shim sem extensão não é visto pelo cmd:

- `<nome>.bat` → `hermes -m combo/<nome> %*`  (cmd.exe, PowerShell)
- `<nome>` (shebang bash, `chmod +x`) → `exec hermes -m combo/<nome> "$@"`

Não existe flag `--aux-model` no `hermes`; o modelo auxiliar só se troca em
`auxiliary.compression.model` no config.yaml do profile.

## Antipadrões

- Replicar a mesma cadeia em todos os combos e chamar isso de roteamento.
- Colocar modelo na cadeia sem teste real (metade não existe).
- Usar `cost-optimized` com free sem pricing.
- Distribuir por request quando o cache read domina o input.
- Declarar pronto sem verificar qual modelo atendeu de fato.
