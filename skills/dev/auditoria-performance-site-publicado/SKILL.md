---
name: auditoria-performance-site-publicado
description: Use ao auditar performance de um site publicado.
---

# Auditoria de performance de site publicado

Gatilhos: "o site está lento", auditar performance de uma URL, medir Core Web Vitals de um deploy, Lighthouse em produção/preview/staging, "por que o LCP está alto", relatório de performance para cliente ou time.

Aqui está o **procedimento** de sair de uma URL para um relatório acionável com números próprios. As regras e thresholds de otimização vivem em `dev/frontend-performance` — esta skill não as repete, usa.

## Portões — pular qualquer um invalida a auditoria inteira

### 1. Confirme a URL exata com o usuário antes de medir

Domínio institucional, produção, preview de branch e staging divergem em ordens de grandeza. O usuário quase sempre está olhando o **preview** enquanto o domínio principal serve outro projeto, mais antigo. Medir o alvo errado produz um relatório internamente coerente, cheio de números verdadeiros, e inteiramente inútil.

Pergunte a URL. Não deduza do nome do repositório.

### 2. Confirme que o build servido é o build do repositório

```bash
curl -s --max-time 60 "$U" | grep -oE '<(script|link)[^>]*>'
```

Compare os hashes dos assets (`index-XXXX.js`) com a saída de um build local. Iguais: o repositório é a fonte da verdade e cada achado tem endereço no código. Diferentes: você está auditando código que ninguém mantém — **e a divergência em si costuma ser o achado mais valioso** (correção já commitada, nunca deployada).

### 3. Verifique o HTTP status de todo recurso externo do critical path

```bash
for u in <@imports, CSS de fonte, CDNs>; do
  echo "$(curl -s -o /dev/null -w '%{http_code}' --max-time 25 "$u")  $u"
done
```

Recurso render-blocking que retorna **404 continua bloqueando o render** pelo tempo do roundtrip, e ainda mata em silêncio o que declarava. Cruze com `tailwind.config` / `index.css`: se a família de fonte declarada vem de um CSS morto, o site inteiro renderiza em fallback do sistema e ninguém percebeu.

A assinatura no Lighthouse é inconfundível: `render-blocking-resources` com `wastedMs` alto e `totalBytes: 0`.

## Medição

Campo vem primeiro quando há chave. CrUX API e PageSpeed Insights API respondem 403/429 sem chave — nesse caso meça em lab e **rotule o relatório como lab**.

```bash
npx --yes lighthouse@12 "$U" \
  --only-categories=performance \
  --form-factor=mobile --screenEmulation.mobile \
  --throttling-method=simulate \
  --output=json --output-path="$LOCALAPPDATA/Temp/lh.json" \
  --chrome-flags="--headless=new --no-sandbox" --quiet
```

`--quiet` + JSON mantém o stdout pequeno; o relatório se lê do arquivo, nunca do terminal.

Build local para conferir bytes reais: invoque o binário por caminho (`node ./node_modules/vite/bin/vite.js build`) — `npx` abre prompt de instalação em sessão não-interativa. **Não apague `dist/` antes**: o bundler sobrescreve, e `rm -rf` em diretório de build dispara guarda de comando destrutivo à toa.

## Extração — os audits que decidem

Leia o JSON com Python. Em ordem de valor:

| Audit | Responde |
|---|---|
| `largest-contentful-paint-element` | O elemento de LCP e as 4 subpartes com % — decide toda a estratégia |
| `mainthread-work-breakdown` | Script Evaluation vs Style & Layout vs Parse |
| `bootup-time` | Tempo de CPU **por script**, com URL |
| `long-tasks` | `duration` + `startTime` + script culpado |
| `network-requests` | `transferSize`, `resourceType`, `networkRequestTime`, `priority` |
| `render-blocking-resources` | `wastedMs` **e** `totalBytes` |
| `third-party-summary` | Isola se o custo é código próprio ou de terceiro |

```python
import json
a = json.load(open(path, encoding="utf-8"))["audits"]
for t in a["largest-contentful-paint-element"]["details"]["items"]:
    for it in t.get("items", []):
        if "phase" in it:
            print(f"{it['phase']:<14} {it.get('timing',0):9.0f} ms  {it.get('percent')}")
```

Detalhe por tipo de gargalo: `references/leitura-de-lighthouse-json.md`.

## Assinaturas — o que cada padrão de número significa

- **Render delay >90% num elemento de texto** → nenhum byte no caminho crítico; é CPU. Vá para `bootup-time`. Comprimir imagem, trocar formato ou mexer em CDN não move o número em 1 ms.
- **Script Parse & Compile em ms, Script Evaluation em segundos** → o problema não é tamanho de bundle, é o que o código faz ao rodar.
- **Style & Layout alto com CLS zero** → layout recalculado repetidamente sem nada se mover: forced synchronous layout. Confirme com LoAF (`forcedStyleAndLayoutDuration`) ou o insight Forced reflow.
- **Razão bytes/CPU absurda** (poucos KB, segundos de scripting) → aponta o arquivo exato a abrir.
- **`third-party-summary` em 0 ms** → todo o custo é código próprio, portanto inteiramente sob controle do time. Diga isso: muda a conversa de "culpa do martech" para "está nas nossas mãos".

## Achados que a leitura ingênua não pega

- **`React.lazy` não adiou nada.** Code-splitting separa bytes, não separa tempo de CPU: um `<Suspense>` que monta no primeiro render devolve o trabalho para a fila do primeiro paint, e os imports estáticos no topo do módulo lazy entram junto. Antes de elogiar o splitting, confira se existe gate temporal (`IntersectionObserver`, `requestIdleCallback`, montagem pós-LCP).
- **Asset 3D: abra o binário antes de recomendar compressão.** Meshopt/Draco podem já estar aplicados e o custo real ser geometria ou textura na origem. Ver `references/inspecao-assets-3d.md`.
- **Imagem em base64 dentro de JSON** soma quatro penalidades: infla ~33%, sai do caminho de otimização de imagem (nenhum CDN redimensiona ou converte), não é cacheável como imagem, e o decode roda na main thread competindo com o render. Correção: arquivo estático com hash, `width`/`height` explícitos, cache longo; base64 só como formato de upload, nunca de entrega.
- **Tag de terceiro antes do consentimento** é custo de main thread *e* exposição regulatória. Cheque no HTML **servido**, não no repositório: `grep -oE "connect.facebook.net|fbq\(|fbevents" prod.html`, e compare o `startTime` na cascata com o momento em que o gate poderia ter rodado. Se o código local gateia e produção não, o achado é "deploy pendente" e vai à frente das otimizações. Acione `compliance/lgpd-audit`.

## Como escrever o relatório

- **Separe medido de inferido**, e feche com uma seção do que **não** foi verificado (campo/CrUX, desktop, INP real, linha exata do reflow). Lab com `simulate` exagera CPU: serve para ordenar prioridade, não para prometer número final.
- **Inclua uma seção do que já está certo e deve ser protegido.** CLS zero numa página com WebGL, zero terceiros na main thread, Meshopt já aplicado — é trabalho feito. Relatório só de defeitos faz o time refatorar o que estava bom.
- Ancore cada defeito no número que o denuncia **e** no arquivo:linha que o causa.
- Ordene por impacto medido, nunca pela ordem em que os achados apareceram. Feche com tabela de ordem de ataque (ação, custo, efeito medido a atacar) e um budget proposto em métricas e bytes — nunca em `categories:performance`.
- Se auditou o alvo errado antes de corrigir, **renomeie o relatório antigo** em vez de apagar; o contraste entre dois deploys costuma ser informação.

## Skills relacionadas

`dev/frontend-performance` (thresholds, regras e fontes), `compliance/lgpd-audit`, `dev/webapp-testing`, `seo/seo-audit`
