---
name: github-search-scraping
description: Use ao raspar GitHub em massa por tema.
---

# Raspagem em massa do GitHub Search API

Coleta dezenas de milhares de repos por tema (backend, segurança, infra) e monta catálogo curado. Medido: 146 queries → 53.6k repos únicos em 69 min.

## Os três limites que quebram a raspagem ingênua

1. **Teto de 1.000 resultados por query.** `total_count` pode dizer 40.000; a API só entrega 1.000 (10 páginas × 100). Paginar além disso retorna HTTP 422.
2. **30 requisições/min na Search API** (autenticado). Não confunda com o limite `core` de 5.000/h — `gh api rate_limit` mostra `search` separado.
3. **Repos gigantes sem topics escapam de `topic:`.** `grpc/grpc` não tem nenhum tópico; `envoyproxy/envoy` tem `cats`, `corgis`. Varredura só por tópico perde esses.

## Solução 1 — split recursivo por faixa de estrelas

Se `total_count > 1000`, divide a faixa `stars:lo..hi` ao meio e recursa. Cada sub-faixa cabe no teto; a união cobre tudo.

```python
def harvest(base_query, lo, hi, depth=0):
    rng = f"stars:{lo}..{hi}" if hi < MAX_STARS else f"stars:>={lo}"
    res = search(f"{base_query} {rng}", page=1)
    total = res.get("total_count", 0)
    if total == 0:
        return
    if total > 1000 and lo < hi and depth < 14:
        mid = lo + (hi - lo) // 2
        if mid == lo:
            mid = lo + 1          # evita recursão infinita em faixa de largura 1
        harvest(base_query, lo, mid - 1, depth + 1)
        harvest(base_query, mid, hi, depth + 1)
        return
    emit(res["items"])
    for page in range(2, min(10, (min(total, 1000) + 99) // 100) + 1):
        emit(search(f"{base_query} {rng}", page)["items"])
```

O guarda `if mid == lo: mid = lo + 1` é obrigatório — sem ele, faixa de largura 1 com >1000 resultados recursa para sempre.

## Solução 2 — throttle global, não por chamada

```python
_last = [0.0]
SEARCH_INTERVAL = 2.15   # 30 req/min = 2.0s; margem contra 403

def gh_api(path):
    gap = time.time() - _last[0]
    if gap < SEARCH_INTERVAL:
        time.sleep(SEARCH_INTERVAL - gap)
    _last[0] = time.time()
    ...
```

Backoff crescente em 403/429; tratar **422 como fim de faixa, não erro** (retry em 422 só queima cota).

## Solução 3 — dois passes de cobertura depois do temático

Depois da varredura por `topic:`, sempre rode:

1. **Termos amplos sem `in:`** — o GitHub casa name+description+readme+topics. Ex.: `"service proxy stars:1000..2000"`. Rendeu +905 repos que o passe temático perdeu.
2. **`GET /repos/{owner}/{repo}` por nome exato** para uma lista de repos que você *sabe* que devem estar. Determinístico, não depende do índice de busca. Único jeito confiável de garantir `metasploit`, `frida`, `keycloak`, `grpc`.

O passe 2 também revela **redirects de owner** — causa número 1 de falha na curadoria. Repos trocam de org com frequência e o nome que você "sabe" costuma estar obsoleto:

| Nome antigo (o que você lembra) | Canônico atual |
|---|---|
| `tiangolo/fastapi` | `fastapi/fastapi` |
| `casbin/casbin` | `apache/casbin` |
| `prisma/prisma` | `prisma/orm` |
| `microsoft/presidio` | `data-privacy-stack/presidio` |
| `mendableai/firecrawl` | `firecrawl/firecrawl` |
| `amzn/style-dictionary` | `style-dictionary/style-dictionary` |
| `jxnl/instructor` | `567-labs/instructor` |
| `outlines-dev/outlines` | `dottxt-ai/outlines` |
| `NVIDIA/NeMo-Guardrails` | `NVIDIA-NeMo/Guardrails` |
| `klaro-org/klaro` | `kiprotect/klaro` |

A API segue o redirect e devolve o nome canônico; o CSV grava o canônico. Curadoria escrita com o nome antigo não encontra e quebra — por isso a validação com `sys.exit(1)` é obrigatória. Resolva em lote: `gh api /repos/{old}` → `.full_name`.

Cuidado: 404 pode significar **nome errado**, não repo morto (`listmonk/listmonk` → o certo é `knadh/listmonk`; `unjs/unlighthouse` → `harlan-zw/unlighthouse`). Confirme com uma busca antes de descartar.

## Estrutura obrigatória do script

- **JSONL append-only** + `state.json` com queries concluídas = retomável após crash/timeout. Recarregue os ids vistos do JSONL ao iniciar.
- **Escrita de state atomica.** `Path.write_text()` direto falha com `OSError: [Errno 22] Invalid argument` no Windows quando chamado em loop apertado — derruba raspagem de 1h no meio. Use tmp + `replace()` com retry:
  ```python
  def save_state(done):
      tmp = STATE.with_suffix(".tmp")
      for _ in range(5):
          try:
              tmp.write_text(json.dumps({"done": sorted(done)}), encoding="utf-8")
              tmp.replace(STATE)
              return
          except OSError:
              time.sleep(0.5)
  ```
- **Dedupe por `id`** (numérico), nunca por `full_name` — repo renomeado apareceria duas vezes.
- Rodar em background com `nohup ... &`, consultar progresso por `tail` do log. Chamada de terminal em foreground estoura o timeout de 420s.

## Armadilhas de formatação do relatório

- **Nunca** aplique `.replace(",", ".")` na linha inteira de Markdown para separador de milhar: vírgula de descrição vira ponto ("Learn math, programming" → "Learn math. programming"). Use helper isolado: `def nf(n): return f"{n or 0:,}".replace(",", ".")`.
- CSV para Excel: `encoding="utf-8-sig"` (sem BOM, acento quebra).
- Na categorização por palavra-chave, exija `len(kw) >= 6` para casar em texto livre. Termos curtos (`go`, `api`, `ids`) casam em qualquer descrição e inflam a categoria — `topic:python`+`topic:java` genéricos arrastaram TensorFlow e Flutter para "Backend".
- Peso maior para match em `topics` (3) do que em nome/descrição (1).

## Curadoria validada (quando o pedido é "as melhores")

Seleção manual com justificativa, **injetando estrelas/push reais do CSV** e com `sys.exit(1)` se algum nome curado não existir na base. Isso impede número inventado e detecta redirect. Sinalize repo sem push há 18+ meses com marca visível. Para ferramenta ofensiva, inclua aviso de escopo autorizado.

## Dois eixos de curadoria

Catálogo grande pede **duas saídas**, não uma:

- **Por tema** ("o que é") — backend, segurança, infra. Serve pra explorar o domínio.
- **Por função** ("quem usa") — um bloco por papel/profile do sistema, com a coluna final respondendo *para que serve NESTA função*, não o que o README diz.

O eixo por função é o que efetivamente muda a decisão na hora do trabalho. Ao raspar para funções de negócio (marketing, SEO, copy, compliance), baixe `MIN_STARS` para ~100: esses nichos têm muito menos estrela que infra, e o corte de 200 esvazia a categoria.

## Checklist

- [ ] `gh auth status` antes (conta certa ativa)
- [ ] Split por estrelas com guarda `mid == lo`
- [ ] Throttle global 2.15s; 422 = fim, não retry
- [ ] JSONL append + state.json
- [ ] Passe de termos amplos + passe por nome exato
- [ ] `nf()` isolado para milhar; `utf-8-sig` no CSV
- [ ] Curadoria falha alto em nome inexistente

## Scripts de referência

`~/Documents/IGOR/pesquisa/gh-scrape/`: `scrape_github.py` (temático), `cobertura.py` (termos amplos), `por_nome.py` (nome exato), `consolidar.py` (CSV+relatório), `curadoria.py` (seleção validada).
