---
name: glb-asset-optimization
description: Use when compressing or swapping GLB/3D assets.
---

# Otimização de asset 3D sem quebrar o consumidor

Use ao comprimir, otimizar ou substituir asset GLB/glTF num projeto web — gltfpack,
draco, meshopt, compressão de textura.

O formato de um asset 3D é uma **interface**. O código do outro lado depende de detalhes
que o tamanho do arquivo não revela. "Comprimir sem tocar em código" quase nunca é verdade.

## Antes de comprimir: meça onde está o peso

Nunca aceite "comprima o GLB" sem abrir o container. Um GLB é JSON + binário:

```js
const b = fs.readFileSync(p);
const jsonLen = b.readUInt32LE(12);
const j = JSON.parse(b.toString('utf8', 20, 20 + jsonLen));
// texturas embutidas: j.images[i].bufferView -> j.bufferViews[bv].byteLength
```

Some os `bufferView` das `images`. Se as texturas forem 87% do arquivo, `gltfpack -cc`
(que comprime **geometria**) entrega ~5%, não os 75% prometidos. Regra: compressão de
geometria só rende quando a geometria é a maior parte do arquivo.

## As duas formas de o consumidor depender da estrutura

Grep no código antes de trocar o asset:

| padrão no código | o que a compressão quebra |
|---|---|
| `material.name === 'X'`, `REFINO[nome]`, `getObjectByName` | `gltfpack` **funde meshes e materiais** (caso real: 21→3 e 17→14) e nomes somem |
| componentes conexos, vértices soltos, segmentação de partes | `gltfpack` **solda vértices coincidentes** — destrói a separação (177.460→62.802) |

Soldagem não tem flag: `-kn -km -ke` (keep nodes/meshes/extras) **não** a desligam.

## O bounding box mente

Após compressão o bbox pode bater com desvio 0,000000 e a geometria estar destruída
para quem a fatia. Compare o que o código realmente usa: número de primitivas,
componentes conexos, nomes de materiais, contagem de famílias agrupadas.

## Prova, não inspeção

Se existir suíte de teste do asset, rode-a com o arquivo trocado:

```bash
cp asset.glb /tmp/BACKUP.glb
cp comprimido.glb asset.glb
node --test scripts/asset.test.mjs    # caso real: 10/10 -> 5/10
cp /tmp/BACKUP.glb asset.glb          # SEMPRE restaure e confirme o SHA-256
```

Testes bons travam o **SHA-256 do asset** — sinal de que o arquivo é contrato, não detalhe.

## Texturas já otimizadas

WebP vindo de pipeline Blender/Substance costuma já estar no limite. Recomprimir a q85
dá ~10% *perdendo qualidade* — péssima troca em material com transmission/clearcoat.
Para peso em celular fraco, sirva **variante menor por capacidade de device**; não
recomprima o mestre. E confirme antes se o gargalo medido é bytes ou CPU: se for CPU
em rajada, encolher o asset não move o ponteiro.

## Quando remover um asset órfão

Grep o nome do arquivo em todo o código antes. Se um `ATTRIBUTION.md` disser que remover
obriga a rever o crédito no rodapé, **verifique o rodapé** — remoção de asset costuma
expor atribuição desatualizada, que é problema de licença, não housekeeping.
CC BY exige crédito *correto*: creditar o autor errado é pior que não creditar.

## Windows / MSYS

`gltfpack` é binário nativo: caminhos MSYS (`/tmp/x.glb`) falham com "Error saving".
Use caminhos nativos com barra normal (`C:/Users/.../x.glb`) e `$LOCALAPPDATA/Temp`
como scratch.

## Antipadrões

- Recomendar compressão sem abrir o container e sem ler quem consome o asset
- Confiar em bbox idêntico ou inspeção visual como prova de equivalência
- Trocar o asset sem rodar a suíte existente
- Tratar ganho de 5% com risco de regressão visual como vitória

## Skills relacionadas

- `design/threejs-materials` — materiais PBR e como o GLTFLoader os entrega
- `dev/diagnosing-bugs` — quando a regressão só aparece em runtime
