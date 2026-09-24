---
name: frontend-performance
description: Use ao otimizar ou medir performance de frontend web.
---

# Performance de frontend

Gatilhos: LCP, INP, CLS, TTFB, Core Web Vitals, bundle JS grande, página lenta, jank, imagem pesada, webfont, main thread travada, third-party script, performance budget em CI, Lighthouse, PageSpeed.

Otimização baseada em dado de campo, não em score de ferramenta. Toda regra tem número e fonte primária.

## Ordem de ataque (siga, não pule)

1. **Meça em campo antes de tocar em código.** CrUX/RUM p75, segmentado mobile/desktop. Sem isso você otimiza o que não dói.
2. **Quebre a métrica em subpartes.** LCP e INP têm breakdown — o gargalo quase nunca é onde a intuição aponta.
3. **Corrija o critical path** (`<head>`, TTFB, descoberta do recurso de LCP).
4. **Corte JS e third-party.**
5. **Só então** micro-otimize render/CSS.
6. **Trave com budget em CI** ou a regressão volta no sprint seguinte.

## Thresholds (p75 de page views, mobile e desktop separados)

| Métrica | Bom | Ruim |
|---|---|---|
| LCP | ≤ 2.500 ms | > 4.000 ms |
| INP | ≤ 200 ms | > 500 ms |
| CLS | ≤ 0,1 | > 0,25 |
| FCP | ≤ 1.800 ms | > 3.000 ms |
| TTFB | ≤ 800 ms | > 1.800 ms |

"Bom" = ≥75% das page views dentro do limite. TTFB e FCP são **diagnóstico**, não meta.
<https://web.dev/articles/defining-core-web-vitals-thresholds>

## LCP — as 4 subpartes

TTFB + resource load delay + resource load duration + element render delay = 100%, sem gap.
Distribuição-alvo: **TTFB ~40%, load delay <10%, load duration ~40%, render delay <10%**. Tudo com "delay" no nome tende a zero.

Dados de campo Chrome (origens "poor", LCP de imagem): TTFB 2.270 ms, load delay 1.290 ms, load duration 350 ms, render delay 360 ms. **A imagem espera 4× mais para começar a baixar do que para baixar.** Comprimir a imagem quase nunca é a correção.
<https://web.dev/blog/common-misconceptions-lcp> · <https://web.dev/articles/optimize-lcp>

Regras:
- Imagem de LCP em `<img src>` no HTML inicial. Nunca `loading="lazy"` (9,5% das páginas erram isso; A/B do web.dev: remover lazy do arquivo melhorou LCP 13% desktop / 15% mobile).
- Exatamente **1–2** `fetchpriority="high"` por página. Mais que isso anula a priorização. Google Flights: 2,6 s → 1,9 s.
- Nunca `data-src` acima da dobra nem imagem injetada por JS — invisível ao preload scanner.
- `background-image` CSS como LCP exige `<link rel=preload as=image fetchpriority=high>`; o scanner lê markup, não CSSOM.
- `fetchpriority="low"` nos slides 2–4 de carrossel (o browser promove mesmo com lazy).
<https://web.dev/articles/fetch-priority> · <https://web.dev/articles/lcp-lazy-loading>

## INP — as 3 subpartes

input delay + processing duration + presentation delay.
- input delay alto → a interação foi vítima de outro trabalho na main thread
- processing alto → o handler é o culpado
- presentation alto → style/layout/paint

Só clique, toque e tecla contam. Scroll e hover não.

Regras:
- No handler, faça **só o que muda o pixel do próximo frame**. O resto vai para `requestAnimationFrame(() => setTimeout(fn, 0))` (cross-browser) ou `scheduler.postTask({priority:'background'})`.
- Ceda a thread com `await scheduler.yield()` — a continuation tem prioridade acima de tasks novas, enquanto `setTimeout(fn,0)` vai para o fim da fila atrás de terceiros e sofre clamp de 5 ms. Chromium 129+, Firefox 142+, Safari não: use `globalThis.scheduler?.yield` (identificador puro lança ReferenceError antes do `?.`) ou `scheduler-polyfill`.
- **Não use `isInputPending()`** — desrecomendado oficialmente.
- `queueMicrotask` / `await Promise.resolve()` **não cedem** a thread.
- Long task = >50 ms; o excedente é blocking period.
- DOM: alerta >800 nós, excessivo >1.400.
<https://web.dev/articles/optimize-inp> · <https://web.dev/articles/optimize-long-tasks> · <https://developer.chrome.com/blog/use-scheduler-yield>

### LoAF encontra o culpado em produção
`long-animation-frame` (Chrome 123+) entrega `blockingDuration`, `renderStart`, `forcedStyleAndLayoutDuration` e o array `scripts` com `invoker`, `sourceURL`, `sourceFunctionName`. Substitui Long Tasks API, que não dizia qual script era. Já vem na `web-vitals` v4+. Use `crossOrigin="anonymous"` nas tags de terceiros (inclusive GTM) ou perde a atribuição.
<https://developer.chrome.com/docs/web-platform/long-animation-frames>

## Rede e critical path

- Instrumente `Server-Timing: db;dur=121.3, ssr;dur=212.2, cache;desc="HIT"` **antes** de otimizar backend. Sem ele TTFB é caixa preta.
- HTTP/3: ganho é de handshake, não de throughput. Cloudflare: TTFB 176 ms (H3) vs 201 ms (H2) = 12,4%; em página de 1 MB o ganho some; paper WWW'24 mostra QUIC **45,2% pior a 1 Gbps** no Chrome. Deixe o CDN fazer — origins servem ~0% em H3.
- 103 Early Hints: Shopify mediu p75 **FCP −76 ms, LCP −100 ms**. Só vale em navegação, só suporta `preconnect` e `preload`. Cuidado: mascara o TTFB real e pode vazar `Link` headers em rota autenticada servida do cache.
- `preload` **só** para recurso descoberto tarde: fonte em `@font-face`, CSS via `@import`, background-image de LCP. Se já está no HTML, o scanner acha — preload só cria contenção. Preload de imagem sem `fetchpriority` sai com prioridade baixa.
- `preconnect` em ≤ 2–4 origens críticas (com `crossorigin` para fontes, senão a conexão abre duas vezes); `dns-prefetch` no resto.
- Zero `@import` em CSS — é roundtrip no critical path. Divida CSS por `media="(min-width: 64em)"`: sai do critical path com prioridade mínima.
- Script síncrono depois de CSS bloqueante não executa até o CSSOM completar. Se não consulta CSSOM, ponha **acima** do CSS.
- Cache: assets com hash → `max-age=31536000, immutable`; sem hash → `max-age=604800, stale-while-revalidate=86400` + ETag; HTML → `max-age=300, private`; no edge some `stale-if-error=86400`.
- Brotli ≥4 em dinâmico, 11 em estático pré-comprimido. zstd substitui gzip, não Brotli. Em produção ~25% usa Brotli nível 1 (às vezes maior que gzip) — confira o nível.
- Quanto melhor a compressão, **mais vale agrupar**. Teste do Harry Roberts: sem compressão muitos arquivos vencem; com Brotli o arquivo único vence (1.094 vs 1.524 ms). Divida bundles por taxa de mudança, não por rota.
<https://csswizardry.com/2018/11/css-and-network-performance> · <https://csswizardry.com/2023/10/the-three-c-concatenate-compress-cache> · <https://blog.cloudflare.com/http-3-vs-http-2/>

### Speculation Rules
Comece em `eagerness: "moderate"` (200 ms de hover). Limites Chrome: immediate/eager = 50 prefetch, 10 prerender; moderate/conservative = 2 cada, FIFO. Sempre exclua rotas com efeito colateral: `{"not": {"href_matches": "/logout/*"}}`. Em prerender, Notifications/Push/`window.open()`/Clipboard ficam adiadas — audite analytics duplicado.
<https://developer.chrome.com/docs/web-platform/prerender-pages>

## Render, CSS e main thread

- Anime **só** `transform` e `opacity` — únicas resolvidas no compositor. Budget: 16,66 ms a 60 Hz, 8,33 ms a 120 Hz.
- Animação não composta **entra no CLS**; composta é excluída. Rode o audit "Avoid non-composited animations".
- Forced sync layout: insight **Forced reflow** no DevTools (meta: nenhum >30 ms), `[Violation] Forced reflow...` no console, ou `forcedStyleAndLayoutDuration` do LoAF em campo. Lista canônica de getters que forçam layout: <https://gist.github.com/paulirish/5d52fb081b3570c81e3a>
- Batch read-then-write. Ler `offsetWidth` e escrever estilo no mesmo loop é o antipadrão clássico.
- `content-visibility: auto` + `contain-intrinsic-size: auto 600px` **abaixo da dobra**: web.dev mediu 232 ms → 30 ms de rendering; lab independente 825 ms → 172 ms. **Nunca acima da dobra** — equivale a lazy-load no LCP. Sem `contain-intrinsic-size` a scrollbar salta; campo real mostrou regressão de CLS ~0,09, então meça antes/depois.
- Views inativas de SPA: `content-visibility: hidden` preserva o rendering state (melhor que `display:none`).
- `will-change` é hint: aplique por JS no `mouseenter`, remova ao terminar. `* { will-change: transform }` = layer explosion.
- CSS/WAAPI > loop rAF manual: keyframes e transitions rodam fora da main thread. Motion usa WAAPI; GSAP roda na main thread.
- Molas em CSS puro: `linear()` com 25–50 pontos (11 fica robótico).
- View Transitions custam: RUM com ~500k pageviews mediu **+70 ms de LCP** em mobile com `@view-transition { navigation: auto }`; `startViewTransition()` roda na main thread dentro da interação e conta para INP. Callback **síncrono** — faça `fetch` antes.
- `prefers-reduced-motion: reduce` é acessibilidade **e** performance.
<https://web.dev/articles/content-visibility> · <https://www.joshwcomeau.com/animation/css-vs-javascript/>

## Framework (React / Next.js)

- Hidratação é o custo que SSR sozinho não resolve. App Router envolve hidratação em `startTransition`; Pages Router não.
- RSC tira dependências do bundle de verdade (exemplo oficial: `marked` + `sanitize-html` = ~75 KB gzip fora).
- **Barrel files são o maior custo silencioso**: `lucide-react` = 1.583 módulos (~1 MB) vs 3 módulos (~2 KB) com import direto; `@mui/material` = 2.225 módulos. `optimizePackageImports` cortou 28% do build e 40% dos cold starts.
- React Compiler 1.0 (out/2025) memoiza **componentes e hooks** — funções soltas continuam sem cache. Com ele, `React.memo` manual vira ruído. Pine a versão exata se não tiver cobertura e2e.
- Suspense **não** torna o componente dinâmico — quem torna é a API dinâmica; Suspense só marca a fronteira do PPR.
- Benchmark de app idêntico (Pixel 5 + 4G): Marko 28,8 KB → Next.js 16 **176,3 KB** comprimido, com todos em Lighthouse 100. Score alto não significa bundle pequeno.
- Mediana de JS mobile: 558 KB, dos quais **206 KB (44%) nunca executam** no load.
- Virtualize listas longas (TanStack Virtual) — mas tente `content-visibility` antes.
- moment → `date-fns` (300 bytes por função) ou `dayjs` (2 kB).
<https://vercel.com/blog/how-we-optimized-package-imports-in-next-js> · <https://react.dev/blog/2025/10/07/react-compiler-1>

## Mídia

- AVIF com fallback `<picture>` (suporte 94,65%). WebP é 25–34% menor que JPEG; AVIF ~20% além do WebP.
- Calibre a qualidade por DSSIM (Malte Ubl): para JPEG q60 use **AVIF q50 / WebP q65** → 36% e 15% menores com mesma diferença visual.
- `sizes` errado é o desperdício silencioso número 1: o `sizes` mediano é 16% maior que o real no mobile, 43% no desktop; 1 em 5 no desktop é errado a ponto de o browser escolher pior recurso; 1/4 das páginas desktop desperdiça 180 KB+, os 10% piores ~1 MB.
- Não-críticas: `sizes="auto"` + `loading="lazy"` (exige `width`/`height`; Safari ainda não suporta). Críticas: corrija `sizes` à mão, audite com RespImageLint.
- Descritores `w` + `sizes` em layout fluido, não `x`. 3–5 variantes.
- `width` + `height` em **todo** `<img>`/`<video>` — só 32% das imagens têm. Par canônico: atributos no HTML + `img { width:100%; height:auto }`.
- `decoding="async"` fora do LCP.
- GIF → `<video autoplay loop muted playsinline>`: 3,7 MB GIF → 551 KB MP4 → 341 KB WebM. Vídeo sem `poster` não é candidato a LCP — e isso é bom.
- Play manual: `preload="none"` + `poster`.
- Iframes offscreen: `loading="lazy"`. Facade em todo embed: YouTube bloqueia a main thread >1,7 s na mediana; `lite-youtube-embed` renderiza ~224× mais rápido.
<https://almanac.httparchive.org/en/2024/media> · <https://www.industrialempathy.com/posts/avif-webp-quality-settings/>

## Webfonts

- **Só WOFF2, self-hosted.** O argumento do cache compartilhado do Google Fonts morreu no Chrome 86 (cache particionado por Network Isolation Key). Nenhum visitante reaproveita sua Roboto de outro site.
- `font-display: swap` ou `optional`. `preload` + `optional` = zero layout jank desde Chrome 83.
- Elimine CLS do fallback com `ascent-override` / `descent-override` / `line-gap-override` / `size-adjust`. Funciona sem detectar SO em ~90% das fontes do Google Fonts. Tooling: `next/font`, Fontaine. Dataset: `khempenius/font-fallbacks-dataset`.
- Preload de **1–3** fontes above-the-fold. DebugBear: preload correto levou LCP de 1,82 s → 1,24 s; site com **38 fontes preloaded** ganhou >2 s ao remover os preloads. `preload` ignora `unicode-range`.
- Máx. 2 famílias; variable font a partir de 3 pesos (regular+bold+itálicos passam de 500 KB).
- Subset por script com `pyftsubset`.
- Alternativa de raiz ao preload: inline das `@font-face` no `<head>`.
<https://developer.chrome.com/blog/font-fallbacks> · <https://developer.chrome.com/blog/http-cache-partitioning>

## Ícones

SVG inline (crítico) ou sprite `<symbol>`+`<use>`. **Icon font nunca**: 50–200 KB, monocromática, usa Private Use Area, hostil a leitor de tela, quebra sob bloqueio de fonte. Decorativo → `aria-hidden="true"` + `focusable="false"`. Com rótulo → `role="img"` + `aria-label`. Use `currentColor` e `width`/`height` explícitos.

## Third-party e mobile real

- Third-party é a maior fatia do bloqueio de main thread na maioria dos sites. Estratégia: facade → consent-gated → server-side tagging → Partytown (worker).
- Partytown é **redução de risco**, não paralelismo: o total pode ficar marginalmente mais lento, mas o frame não congela. Limite de `postMessage`: >~10 KB de JSON → use `ArrayBuffer`.
- Script de terceiro síncrono no `<head>` = SPOF. Quando a Ad-Tech cai, a página cai junto.
- CPU throttling do DevTools é multiplicador linear: não reproduz thermal throttling, barramento lento nem I/O de silício barato. Calibre contra hardware real de gama média/baixa (Samsung A-series), não contra o Moto G4 emulado herdado.
- Para INP, throttling de CPU ≥4× é **obrigatório** em máquina de dev.
- `@media (prefers-reduced-data: reduce)` corta hero em vídeo e animação decorativa.
<https://csswizardry.com/2025/08/low-and-mid-tier-mobile-for-the-real-world-2025/>

## Budget e CI

- **Budget = "nunca pior do que hoje"**, não meta aspiracional (Harry Roberts): pegue o pior data point das últimas 2 semanas e faça dele o limite; revise a cada 2 semanas. Metas são um documento separado.
- Lighthouse CI: `lhci autorun --collect.numberOfRuns=5`. Asserções em **LCP/TBT/CLS e bytes de JS**, nunca em `categories:performance`. Em autorun, flags de subcomando exigem sintaxe `=`.
- Guardrail (build quebra) + breadcrumb (alerta em RUM) juntos. Guardrail sem breadcrumb dá build vermelha sem causa.
- Alerte só em TTFB, start render e LCP. Alerta demais vira alerta ignorado.
- Cases para defender prioridade: Vodafone +8% de vendas com −31% de LCP; Rakuten 24 +53,37% de receita por visitante.
<https://csswizardry.com/2020/01/performance-budgets-pragmatically/> · <https://web.dev/case-studies/vitals-business-impact>

## Instrumentação de RUM

1. `web-vitals` do **attribution build** (`web-vitals/attribution`), bundle separado do app. ~3 KB brotli, `buffered: true` — não precisa carregar cedo.
2. v5: `onFID()` removido, `LCPAttribution.element` → `.target`.
3. Envie em `visibilitychange`/`pagehide` via `navigator.sendBeacon`, com `metric.id` para deduplicar.
4. Guarde debug signals ou o RUM não serve para agir: LCP → `target`, `url`, 4 subpartes; INP → `interactionTarget`, `interactionType`, 3 subpartes, `longAnimationFrameEntries`; CLS → `largestShiftTarget`, `largestShiftTime`.
5. Corte por form factor, conexão, país, **template** (não URL única), tipo de navegação (nova / bfcache / prerender), logado vs anônimo.
6. Agregue sempre em p75, nunca em média.
7. SPA: Soft Navigations API (`soft-navigation`, `interaction-contentful-paint`) no Chrome 151+, ainda fora da CrUX — mantenha o report de hard navigation em paralelo.

## Antipadrões (custam mais do que parecem)

| Antipadrão | Por quê |
|---|---|
| Perseguir score 100 no Lighthouse | Média ponderada em curva log-normal; de 99→100 custa quase o mesmo que 90→94. Ranking usa CrUX, não Lighthouse |
| Comprimir a imagem para "corrigir LCP" | O tempo migra de load duration para render delay; total não muda |
| Preload em massa | Preload é mandatório, não hint — rouba banda do LCP e do CSS bloqueante |
| `fetchpriority="high"` em 5+ imagens | Achatar prioridades = não ter prioridades |
| `loading="lazy"` na hero | 9,5% das páginas; a degradação mais cara e mais fácil de corrigir |
| `sizes="100vw"` copiado sem conferir | Origem dos 180 KB–1 MB desperdiçados |
| Google Fonts via CDN "porque já tá em cache" | Falso desde o Chrome 86 |
| `font-display: swap` sem métricas de fallback | Troca FOIT por CLS |
| `content-visibility: auto` acima da dobra | Lazy-load do LCP disfarçado |
| `setTimeout(fn,0)` como yield | Clamp de 5 ms e continuation atrás de terceiros |
| `* { will-change: transform }` | Layer explosion, estouro de memória de GPU |
| `await fetch()` dentro de `startViewTransition` | Congela o rendering até a rede responder |
| Critical CSS retrofitado em legado | Frágil, quebra com off-canvas, resolve só o fetch |
| Perfilar em máquina de dev sem throttling | Interação lenta não reproduz |
| Comparar CrUX com RUM próprio e achar que um está errado | CrUX inclui iframes, só Chrome, p75 de 28 dias |
| Budget "político" fora do CI | Sobrevive duas semanas |

## Ferramentas

WebPageTest (sintético profundo) · DebugBear, SpeedCurve, Calibre (RUM + sintético) · Treo (CrUX histórico grátis) · <https://cwvtech.report/> (CWV bom por tecnologia — cheque antes de escolher stack) · bundlejs / Bundlephobia · Lighthouse Treemap e insight "Duplicated JavaScript".

**Lighthouse 13 (out/2025) removeu os audits legados do JSON.** Se seu CI faz parsing de ID de audit, quebrou: `largest-contentful-paint-element` → `lcp-phases-insight`, `render-blocking-resources` → `render-blocking-insight`, `layout-shifts` → `cls-culprits-insight`, `work-during-interaction` → `interaction-to-next-paint-insight`.

## Quem seguir

| Pessoa | Tese em uma linha |
|---|---|
| Alex Russell (infrequently.org) | Device reality define o budget; JS custa ~3× por byte. P75 global: 1,3 MiB total, 650 KB de JS |
| Harry Roberts (CSS Wizardry) | O `<head>` e o critical path explicam a maior parte do ganho |
| Addy Osmani | Budget antes da feature; "cost of JavaScript" é download **e** execução |
| Barry Pollard | CWV se mede em campo; priorize o LCP explicitamente |
| Philip Walton | Lab ≠ campo; "idle until urgent" |
| Tim Kadlec | Otimize a cauda (p75–p95), não a mediana. Performance é inclusão |
| Jake Archibald | Teste em device de entrada com rede degradada |
| Paul Irish | Nunca leia geometria dentro de loop que escreve estilo |
| Una Kravets | CSS moderno resolve o que se atacava com JS |
| Josh Comeau / Emil Kowalski | Anime `transform`/`opacity`; <300 ms e `ease-out` para resposta a input |
| Jason Miller | Islands: hidrate só o que precisa ser interativo |
| Tammy Everts | Traduza métrica técnica em métrica de negócio antes de pedir prioridade |

Recursos canônicos: <https://web.dev/learn/performance> · <https://almanac.httparchive.org/en/2025/performance> · <https://calendar.perfplanet.com/> · <https://perfnow.nl/>

## Skills relacionadas

`design/gsap-performance`, `design/fixing-motion-performance`, `dev/webapp-testing`, `seo/seo-audit`, `design/mobile-native`
