---
name: frontend-craft
description: Use quando a UI fica básica ou parece template.
---

# Frontend Craft — regras de aparência

Use ao projetar, revisar ou consertar a **aparência** de uma interface web: site que "fica básico", "parece template", "parece feito por IA", ou que precisa de acabamento visual. Para **velocidade** use `dev/frontend-performance` — esta skill é sobre aparência.

Tese: "parece limitado" quase nunca é falta de tecnologia. É ausência de decisão — o site herdou os defaults do framework, do gerador e do tutorial, e default é a média de tudo que já existe.

Pesquisa completa (8 eixos, 186 regras, 199 fontes verificadas): `C:\Users\judon\Documents\IGOR\pesquisa\fe_craft\README.md`

## Diagnóstico primeiro (3 testes, sem ferramenta)

1. **Squint test** — blur de 5, 10 e 20 px sobre a tela. Com 5-10 px os agrupamentos pretendidos devem continuar legíveis; com 20 px aparece a hierarquia *não intencional*. Se as três coisas importantes têm o mesmo peso de cinza, achou o problema.
2. **Troca de logo** — troque seu logo pelo do concorrente. Ninguém notou? O site não tem decisão visual própria.
3. **Dedo apontado** — 5 pontos aleatórios da tela, explique cada um. Qualquer "veio do template" é decisão não tomada.

Por que importa: o veredito estético sai em **50 ms** (Lindgaard et al. 2006, ~10× mais rápido que ler) e quase não muda depois. Kurosu & Kashimura (1995, 26 UIs, 252 participantes): beleza percebida correlaciona mais com facilidade *percebida* do que com facilidade real.

## Hierarquia — tem teto numérico (NN/g)

- **≤3 tamanhos** de texto, **≤2 elementos grandes** por tela, **≤3 variações de contraste**, 2 cores primárias + 2 secundárias.
- Sintoma do template: um único nível — tudo 15-18px, weight 400, mesma cor.
- Crie hierarquia **rebaixando o secundário**, não gritando com o primário (Refactoring UI).
- Use **peso e cor antes de `font-size`**. Nunca `font-weight` < 400 em UI — para rebaixar, use cor.
- Signifiers fracos custam **+22% de tempo e +25% de fixações** (NN/g, 71 participantes, 9 sites, p<0,05). Flat demais tem custo medido.

## Cor

- Tokens em **`oklch()`** — `L` é lightness *percebida*. Em HSL, `hsl(60 100% 50%)` e `hsl(240 100% 50%)` declaram a mesma lightness e não parecem nem de longe igualmente claros. Baseline Widely Available desde 09/11/2025. LCH tem hue shift entre 270 e 330; OKLCH não.
- **Nunca `#000` nem `#fff` puros.** Near-black / near-white.
- **Sature os neutros** com <5% (HSB) da matiz da marca — é o sinal nº1 de site projetado. Tailwind v4: `slate-500` = `oklch(55.4% 0.046 257.417)` vs `neutral-500` = `oklch(55.6% 0 0)`.
- Uma temperatura só: quente **ou** frio, nunca os dois.
- Rampa de 9-11 tons pelas bordas (100/500/900 → 300/700 → resto). Cinco hex de gerador não constroem nada.
- Estados derivados com `color-mix()` / relative color syntax, não 12 hexes hardcoded.
- **Dark mode não é inversão**: banda 200-50 da paleta, fundo cinza-escuro (não `#000`), elevação por **Surface Tint** (+4 a 12% de lightness por nível), **zero sombra**.
- Gradiente: interpole `in oklab` para evitar a zona cinza morta.
- Contraste é o defeito nº1 da web: **83,9%** das home pages têm texto de baixo contraste (WebAIM Million 2026, 34 instâncias/página). WCAG 2.x não serve para projetar dark — use APCA (Lc 90 corpo, Lc 75 mínimo).

## Tipografia

- Body **≥16px**. Measure **60-75ch**. `line-height` sem unidade: 1,4-1,5 no corpo, 1,05-1,1 no display.
- **`letter-spacing` negativo acima de ~32px** (-0.01em a -0.04em) — é o detalhe que mais separa amador de profissional. Caps pequenas: +0.05em a 0.12em.
- **Máximo 2 famílias.**
- `text-wrap: balance` em headings (limite de 6 linhas), `text-wrap: pretty` em parágrafos.
- `font-variant-numeric: tabular-nums` em tabelas e dashboards; `slashed-zero` onde couber.
- `font-optical-sizing: auto` em variable fonts.
- `text-box-trim: trim-both; text-box-edge: cap alphabetic` (Chrome 133 / Safari 18) elimina o half-leading e torna o padding de botão simétrico de verdade.
- `clamp()` fluido: razão teto/piso **≤2,5×**, senão quebra o zoom de 500% do WCAG 1.4.4.

## Espaço e layout

- **Proximidade de Gestalt é o que gera hierarquia**: espaço *entre* grupos >> espaço *dentro* do grupo. `gap: 24px` uniforme em tudo é o erro nº1 de dev.
- Escala modular com saltos ≥25%, não múltiplos lineares.
- **Padding externo do container ≥ padding interno.**
- Botão: **padding inline = 2× o block**.
- Tudo alinhado a alguma outra coisa; alinhamento óptico > matemático.
- `subgrid` para alinhar conteúdo entre cards irmãos; container queries (`container-type: inline-size`) para componente que responde ao slot, não à viewport.
- Full-bleed com grid nomeado (`[full-start] 1fr [main-start] minmax(auto, 65ch) [main-end] 1fr [full-end]`), não `100vw` com margem negativa.
- Espaçamento vertical por relação entre irmãos (`* + *`), não margem em cada item.

## Profundidade e superfície

- **Sombra de camada única é o que chapa a UI.** Empilhe 3-5 `box-shadow`, blur crescente, alpha decrescente.
- **Blur = 2× a distância Y.**
- **Tinja a sombra** com a matiz do fundo — `rgba(0,0,0,.2)` puro dessatura em vez de escurecer.
- Uma única fonte de luz no site inteiro (mesmo ângulo, mesma cor).
- Highlight inset de 1px (`inset 0 1px 0 rgba(255,255,255,.1)`) é o acabamento de UI escura estilo Vercel/Linear.
- **Raio aninhado**: raio interno = raio externo − distância. Raio igual em pai e filho parece errado.
- Borda de container contrasta com os **dois** fundos, nunca valor intermediário.
- **Não misture técnicas de profundidade** — escolheu sombra suave, use sombra suave em tudo.
- Nunca duas divisões duras adjacentes (borda + transição de fundo no mesmo ponto).
- Grão via `feTurbulence` SVG mata o banding e o aspecto plástico do gradiente.
- Simples sobre complexo ou complexo sobre simples — nunca complexo sobre complexo.

## Motion

- Micro-interações **100-200 ms**; superfícies grandes 250-400 ms; acima de 500 ms é raro estar certo.
- **`ease-out` para entrada, `ease-in` para saída.** Nunca `linear`, nunca o `ease` default.
- Anime a partir do gatilho (`transform-origin` no botão que abriu).
- Toda animação **interruptível e reversível**.
- `@starting-style` + `transition-behavior: allow-discrete` para entrada sem JS; `interpolate-size: allow-keywords` para animar até `height: auto`.
- `animation-timeline: view()` substitui biblioteca de scroll-reveal.
- `prefers-reduced-motion` é obrigatório.
- Scroll-reveal em tudo é marca de site amador. Não anime o que o usuário repete o dia inteiro.

## 3D / WebGL

- Só se a superfície for o **gancho emocional** do site. Dashboard e e-commerce padrão: não.
- Esgote CSS antes (`mask-image`, `mix-blend-mode`, `clip-path`, `backdrop-filter`, `conic-gradient`, Houdini `paint()`).
- `InstancedMesh` para milhares de objetos; DPR em `Math.min(devicePixelRatio, 2)`; Draco/Meshopt no GLB.
- Trate `webglcontextlost`, faça `dispose`, e sirva `<img>` estático como fallback de LCP.

## Conteúdo (o que o CSS não conserta)

- **Stock photo é pixel jogado fora**: foto real da empresa recebeu +10% de tempo de olhar que bios ocupando 316% mais espaço; foto de modelo genérica é ignorada. Amazon: 82% do tempo no texto, 18% nas fotos (0,9 vs 4,4 fixações).
- Copy vaga ("Soluções inovadoras") é o equivalente textual do gradiente roxo.
- Estados vazio, erro e carregando fazem parte do design — a ausência deles é o que mais denuncia template.

## Antipadrões — a assinatura do slop

- Gradiente roxo→azul-violeta no hero + Inter sem ajuste + cantos muito arredondados.
- Cinza puro (`#666`, `#999`) em interface que tem cor de marca.
- `gap` e `padding` idênticos em toda a página.
- Grid de 3 cards idênticos; hero com título centralizado + subtítulo + dois botões.
- Sombra default do framework, igual em todos os níveis.
- `border-radius` uniforme em tudo, sem aninhamento.
- Ícones soltos sem sistema (tamanho, stroke e contraste ad hoc).
- Hover/focus não pensados; `:focus-visible` esquecido.
- `font-weight: 300` em UI.
- `* { will-change: transform }` e scroll-reveal em cada seção.

## Loop de trabalho

Saída de IA (inclusive a sua) é **rascunho**, não entrega. 470 PRs analisados: código gerado por IA teve 1,7× mais issues e 2,74× mais vulnerabilidades. Trabalhe em ciclo fechado:

**build → crítica (squint test + dedo apontado) → corrigir o de maior impacto → reavaliar.**

Nunca aceite a primeira resposta. Comece em escala de cinza e só depois colora — força a hierarquia a existir sem depender de cor.
