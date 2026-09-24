# Peso de assets: GLB, fontes e o que medir

## Soldar antes de simplificar

Se `gltf-transform` devolve o MESMO tamanho por mais que se aperte
`--simplify-ratio` (0.45, 0.25, 0.12 → todos iguais), a malha não está soldada.

Sintoma no `inspect`: vértices ≈ 2,5–3× os triângulos. O logo desta plataforma
tinha 571k vértices para 222k triângulos. Cada face carrega as próprias
normais, todo vértice é uma costura, e o simplificador não tem aresta para
colapsar — recusa em silêncio e devolve o ficheiro intacto.

O `weld` do CLI compara todos os atributos, incluindo NORMAL, e nesse caso não
solda nada. É preciso descartar as normais primeiro, via API:

```js
for (const prim of malha.listPrimitives()) prim.setAttribute('NORMAL', null);
await doc.transform(dedup(), weld(), simplify({ simplifier: MeshoptSimplifier, ratio, error: 0.02 }));
// recalcular as normais DEPOIS, com limiar de ângulo
```

O limiar importa: somar cegamente todas as faces que tocam um vértice lava as
arestas vivas da extrusão. ~65° separa o canto de 90° da curvatura suave.
Preservar hard edges duplica vértices nos cantos e custa ~25% do ficheiro — é
o preço certo a pagar.

**Alvo explícito: menos de 65.535 vértices.** Acima disso os índices são u32;
abaixo passam a u16. No logo, só essa mudança cortou 1,86 MB de 2,5 MB.

Se o `inspect` mostrar o peso nas TEXTURAS e não na malha (o iPhone: 1,4 MB de
mapas contra 260 KB de geometria), simplificar não faz nada — é
`--texture-size` que resolve.

Resultado obtido: logo 2.524→590 KB, iPhone 1.595→585 KB. Total −71%.

## Escolher o nível por pixel, não por olho

A inspeção visual assistida descreveu "dígitos 3, 6, 0 com facetas escuras"
num modelo que não tem um único caractere de texto — `glyph_E-Mesh` é o globo
geodésico. Várias iterações foram gastas a perseguir esse defeito inexistente.

Renderizar cada variante e contar pixels que desviam acima do limiar do
visível dá número comparável:

```
logo   ratio 0.20 (298 KB): 2,12% dos pixels desviam >8
logo   ratio 0.45 (590 KB): 1,01%  ← escolhido
iphone 512px     (585 KB): 0,32%, e 0,00% acima de 24  ← escolhido
```

Antes de julgar, **confirmar o que está enquadrado**. Duas medições deram
números idênticos entre 1024px e 512px porque a câmara mostrava a TRASEIRA do
iPhone, onde não há mapa de ecrã nem roughness pesado. O modelo tem o ecrã em
−Z.

## Renderizar sem o browser partilhado

O Chrome partilhado tem as abas sequestradas por outros dev servers: mede-se a
página errada e parece bug da app. O `gl` do Node é WebGL 1 e o three moderno
exige WebGL 2 (`texImage3D`). O que funciona é Playwright com Chromium próprio:

```bash
chromium.launch({ args: ['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'] })
```

E servir os ficheiros por http — uma página em `data:` não consegue buscar
`file://`, e o loader falha em silêncio.

## Fontes: o pacote `geist` não tem CSS

Os `@import` para `cdn.jsdelivr.net/npm/geist@1/dist/fonts/geist-sans.css`
davam 404 desde sempre: **o pacote não publica ficheiro `.css` nenhum**, só
WOFF2. Não era CDN em baixo.

As variáveis são `dist/fonts/geist-sans/Geist-Variable.woff2` e
`dist/fonts/geist-mono/GeistMono-Variable.woff2`, 138 KB para todos os pesos de
100 a 900 — e este CSS usa 450, 550, 750, 820, 850, que só existem em fonte
variável.

Servir do próprio domínio, e nunca reintroduzir `@import` de CDN para fonte: um
`@import` no topo do CSS é sequencial, o browser só descobre a fonte depois de
baixar e analisar a folha.

### `size-adjust` medido, não estimado

Sem isso, a troca do fallback para a fonte real desloca o texto e gera CLS.
Medir a largura de 'a-z' **no DOM**, não em `canvas.measureText`: o canvas mede
sem kerning nem shaping e deu 1387,9 contra os 1339 reais — 4 pontos
percentuais de erro no `size-adjust`.

Geist 1339 px / Segoe UI 1283 px = `size-adjust: 104.36%`. Resultado: CLS
0,0000 local, 0,0146 em produção.

## Ganho medido

Com CPU 4× estrangulada e 4G lento (sem isso o número mente):

| | antes | local | produção (EU) |
|---|---|---|---|
| LCP | 27,5 s | 4,72 s | 8,51 s |
| CLS | — | 0,0000 | 0,0146 |
| peso | ~5 MB | 1,26 MB | 1,29 MB |
