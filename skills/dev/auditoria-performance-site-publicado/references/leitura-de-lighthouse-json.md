# Leitura do JSON do Lighthouse

O HTML do Lighthouse é para humano; o JSON é para diagnóstico. Estes são os caminhos que respondem perguntas, com o recorte de campos que importa.

## Esqueleto

```python
import json
d = json.load(open(path, encoding="utf-8"))
print(d.get("finalDisplayedUrl"), d["categories"]["performance"]["score"])
a = d["audits"]
for m in ["first-contentful-paint", "largest-contentful-paint", "total-blocking-time",
          "cumulative-layout-shift", "speed-index", "interactive", "server-response-time"]:
    if m in a:
        print(f"  {m}: {a[m].get('displayValue')}")
```

`finalDisplayedUrl` confirma que não houve redirect para outro alvo — confira sempre, é barato.

## Subpartes do LCP

```python
for t in a["largest-contentful-paint-element"]["details"]["items"]:
    for it in t.get("items", []):
        if "node" in it:
            print(it["node"].get("selector"), "|", (it["node"].get("nodeLabel") or "")[:70])
        if "phase" in it:
            print(f"   {it['phase']:<14} {it.get('timing',0):9.0f} ms  {it.get('percent')}")
```

As quatro fases (TTFB, Load Delay, Load Time, Render Delay) somam 100%. O `nodeLabel` diz se o LCP é imagem ou texto — se é texto, nenhuma otimização de mídia toca no número.

## Custo de CPU por script

```python
for it in a["bootup-time"]["details"]["items"][:12]:
    print(f"  total={it.get('total'):8.0f}ms script={it.get('scripting'):8.0f}ms "
          f"parse={it.get('scriptParseCompile'):6.0f}ms  {str(it.get('url'))[:80]}")

for it in a["mainthread-work-breakdown"]["details"]["items"][:10]:
    print(f"  {it.get('duration'):9.0f}ms  {it.get('groupLabel')}")
```

Cruzar `transferSize` (de `network-requests`) com `scripting` (daqui) dá a razão bytes/CPU. Um script de poucos KB com segundos de scripting é o arquivo a abrir primeiro.

`Unattributable` alto costuma ser trabalho de framework disparado por timer ou observer — olhe os `long-tasks` vizinhos no tempo.

## Long tasks com autoria

```python
lt = a["long-tasks"]["details"]["items"]
for it in lt[:12]:
    print(f"  dur={it.get('duration'):7.0f}ms start={it.get('startTime'):8.0f}  {str(it.get('url'))[:78]}")
```

`startTime` importa tanto quanto `duration`: long tasks que começam bem depois do paint observado revelam loop de scroll/render, não inicialização.

## Cascata

```python
for it in sorted(a["network-requests"]["details"]["items"],
                 key=lambda x: -(x.get("transferSize") or 0))[:14]:
    print(f"  {(it.get('transferSize') or 0)/1024:8.1f}KB {str(it.get('resourceType')):<11} "
          f"{str(it.get('url'))[:78]}")
```

Para ordem temporal, troque a chave por `networkRequestTime` e imprima também `priority`. Asset pesado com prioridade `High` disparado antes do DOMContentLoaded compete por banda com o primeiro paint — o alvo é adiar, não só encolher.

## Paint observado vs métrica creditada

```python
m = a["metrics"]["details"]["items"][0]
for k in ["observedFirstContentfulPaint", "observedLargestContentfulPaint",
          "observedDomContentLoaded", "observedLoad", "observedSpeedIndex"]:
    print(f"  {k}: {m.get(k)} ms")
```

Quando o paint observado é muito menor que o LCP creditado, a página pintou cedo e **não estabilizou** — trabalho contínuo depois do paint. Aponta para animação, WebGL ou loop de scroll, não para entrega de recurso.

## Render-blocking

```python
for it in a["render-blocking-resources"]["details"]["items"]:
    print(f"  wasted={it.get('wastedMs')}ms total={it.get('totalBytes')}B {str(it.get('url'))[:75]}")
```

`totalBytes: 0` com `wastedMs` alto = recurso morto que ainda bloqueia. Confirme o status com `curl`.

## Aviso de versão

Lighthouse 13 (out/2025) removeu os audits legados do JSON. CI que faz parsing de ID de audit quebra sem aviso:

| Antigo | Novo |
|---|---|
| `largest-contentful-paint-element` | `lcp-phases-insight` |
| `render-blocking-resources` | `render-blocking-insight` |
| `layout-shifts` | `cls-culprits-insight` |
| `work-during-interaction` | `interaction-to-next-paint-insight` |

Fixe a major (`lighthouse@12`) ao escrever scripts de extração, ou trate os dois nomes.
