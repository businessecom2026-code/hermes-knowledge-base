# Fontes primárias para pesquisa de frontend

Lista curada para alimentar `web_extract` diretamente. Buscar no motor de busca por estes temas devolve fazenda de SEO; ir direto na fonte devolve conteúdo com número.

## Transversais (servem a qualquer eixo)
- `developer.mozilla.org` — referência de propriedade/API. Sempre a versão `/en-US/docs/Web/...`; a tradução pt-BR fica defasada.
- `web.dev/articles/...` e `web.dev/blog/...`
- `developer.chrome.com/docs/...` e `/blog/...` — o que está chegando no Chromium, com números de versão.
- `html.spec.whatwg.org`, `drafts.csswg.org` — quando o comportamento é disputado.

## Performance
- `httparchive.org/reports` e o Web Almanac — percentis de campo reais.
- `csswizardry.com` — rede, cascata de carregamento.
- `developer.chrome.com/docs/web-platform/long-animation-frames` — LoAF.
- `react.dev`, `nextjs.org/docs` — hidratação, RSC, compiler.

## Craft visual — tipografia
- `utopia.fyi` — escala fluida de tipo e espaço com `clamp()`.
- `practicaltypography.com` — medida, entrelinha, escolha de família.
- `rsms.me/inter` — notas do autor sobre optical sizing e features.
- `smashingmagazine.com` — acessibilidade de fluid type (zoom 200%, WCAG 1.4.4).

## Craft visual — cor
- `evilmartians.com/chronicles/oklch-in-css-why-quit-rgb-hsl` — a peça de referência sobre OKLCH.
- `joshwcomeau.com/css/color-formats/`
- `developer.chrome.com/docs/css-ui/high-definition-css-color-guide` — gamut amplo, P3.
- `refactoringui.com/previews/building-your-color-palette`

## Craft visual — layout e espaço
- `every-layout.dev` — axiomas de composição.
- `css-tricks.com/snippets/css/complete-guide-grid/`
- `joshwcomeau.com/css/interactive-guide-to-flexbox/`

## Craft visual — profundidade e superfície
- `joshwcomeau.com/css/designing-shadows/` — sombra em camadas, fonte de luz coerente.
- `css-tricks.com/grainy-gradients/` — grão via `feTurbulence` contra banding.

## Motion e interação
- `emilkowal.ski/ui/...` — propósito, interrupção, easing e duração por tipo de elemento.
- `joshwcomeau.com/animation/...`
- `motion.dev/docs/...`
- `rauno.me/craft` — detalhes de interação.

## Regras visuais com número
- `anthonyhobday.com/sideprojects/saferules/` — 28 regras de design visual com valores duros (near-black/near-white; saturar neutros abaixo de 5%; brilho container↔fundo dentro de 12% no dark e 7% no light; blur da sombra = 2× a distância Y; raio interno = raio externo − distância; no máximo 2 famílias tipográficas; padding externo ≥ padding interno; medida ~70 caracteres; sem sombra em UI escura; não misturar técnicas de profundidade).
  **Exige fallback:** `web_extract` devolve a página truncada e o caminho antigo `/sites/saferules/` responde 404. Baixar com `curl -sL -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"` e limpar as tags.
- `nngroup.com/articles/...` — efeito estética-usabilidade e pesquisa de UX com método.

## Referência do campo (para o eixo de personalidades)
- `vercel.com/blog/design-engineering-at-vercel`, `maggieappleton.com/design-engineers` — o que é design engineering.
- `linear.app/method`, `rauno.me/craft`, `paco.me` — padrões de acabamento de produto.
