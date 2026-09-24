# Inspeção de assets 3D (GLB / glTF) numa auditoria

Nunca recomende "comprimir o modelo" sem abrir o binário. Draco ou Meshopt podem já estar aplicados — e nesse caso a recomendação genérica faz o time refazer trabalho já feito, enquanto o custo real (contagem de triângulos, resolução de textura) continua intocado.

## Ler o header sem dependência

GLB é um container: 12 bytes de header, depois um chunk JSON. Dá para inspecionar com stdlib.

```python
import json, struct
b = open(path, "rb").read()
jl = struct.unpack("<I", b[12:16])[0]
g = json.loads(b[20:20+jl].decode("utf-8"))

print(f"{len(b)/1048576:.2f} MB")
print("extensionsUsed:", g.get("extensionsUsed"))
print("meshes:", len(g.get("meshes", [])), "| materials:", len(g.get("materials", [])))

tris = sum(g["accessors"][pr["indices"]]["count"] // 3
           for m in g.get("meshes", []) for pr in m.get("primitives", []) if "indices" in pr)
print(f"triangulos: {tris:,}")

for i, im in enumerate(g.get("images", [])):
    bv = im.get("bufferView")
    sz = g["bufferViews"][bv]["byteLength"] if bv is not None else 0
    print(f"  img{i}: {im.get('mimeType')} {sz/1024:.0f} KB")
```

## Como ler o resultado

`extensionsUsed` é o primeiro portão:

| Presente | Significa |
|---|---|
| `EXT_meshopt_compression` | Geometria já comprimida — não recomende Draco por cima |
| `KHR_mesh_quantization` | Atributos já quantizados |
| `EXT_texture_webp` | Texturas já em WebP; o passo seguinte é KTX2/Basis, não WebP |
| `KHR_draco_mesh_compression` | Alternativa a Meshopt; decodifica mais lento na main thread |

Com compressão já aplicada, as alavancas restantes, em ordem de retorno:

1. **Decimar malha.** Dezenas de milhares de triângulos bastam para um objeto de tela. Centenas de milhares num logo ou ícone é modelagem para impressão servida na web — costuma ser o maior corte de bytes disponível, e visualmente indistinguível.
2. **Reduzir resolução de textura.** Some os KB por imagem: em modelos de produto, duas texturas costumam concentrar a maior parte do peso.
3. **KTX2 / Basis** em vez de WebP/PNG: descomprime direto na GPU, sem passar pela main thread.
4. **Brotli no transporte.** GLB com Meshopt ainda ganha; confira se há `Content-Encoding` na resposta.
5. **Cache.** Com hash no nome, `max-age=31536000, immutable`. `max-age=86400` num asset imutável joga fora o repeat visit.

## O que checar na entrega

```bash
curl -sI --max-time 60 -H "Accept-Encoding: gzip, br" "$URL_DO_GLB" \
  | grep -iE "^HTTP|content-encoding|content-length|cache-control|content-type"
```

`Content-Type: text/html` numa URL `.glb` significa que a rota caiu no fallback da SPA — o arquivo não existe nesse caminho. Confira o nome real no diretório público: divergências de sufixo (`-max`, versão) passam despercebidas porque a SPA responde 200 para tudo.

## Timing importa mais que tamanho

Na cascata (`network-requests`), veja `networkRequestTime` e `priority` do GLB. Disparado com prioridade `High` antes do DOMContentLoaded, ele compete por banda com o primeiro paint. Encolher o arquivo ajuda; **tirá-lo do caminho do primeiro paint** ajuda mais — carregue a cena depois do LCP, via `IntersectionObserver` no container.
