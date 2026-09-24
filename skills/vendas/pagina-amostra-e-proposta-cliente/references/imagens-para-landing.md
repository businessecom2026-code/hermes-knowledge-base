# Imagens reais para landing de amostra

Amostra com placeholder cinza não vende. O cliente precisa ver a página como se fosse dele.

## Nunca escreva ID de foto de memória

IDs de Unsplash/Pexels "lembrados" retornam imagens de assunto completamente diferente —
pediu tear industrial, veio interior de café — e o erro só aparece quando o cliente olha.
Sempre busque por API e valide o arquivo baixado.

## Openverse: API aberta, sem chave, filtro de licença comercial

```python
from urllib.parse import urlencode
url = "https://api.openverse.org/v1/images/?" + urlencode({
    "q": q, "page_size": 15,
    "license_type": "commercial",   # seguro para uso comercial
    "size": "large",
})
# resposta: results[].url (arquivo direto), .title, .license, .foreign_landing_url
```

Baixe com `User-Agent` de navegador; alguns hosts de origem recusam cliente sem UA.
Guarde `title` + `license` + URL de origem num `CREDITOS.txt` ao lado das imagens —
licença comercial ainda costuma exigir atribuição, e a checagem fica barata depois.

## Valide CADA arquivo baixado antes de usar

Passe por `vision_analyze` perguntando assunto e cor dominante. Descarte:

- assunto errado (busca por "textile mill" devolve muito interior de museu e maquinaria agrícola);
- acervo histórico em P&B quando a página precisa parecer atual;
- imagem com marca d'água, texto embutido ou logo de terceiro;
- foto onde o produto aparece pequeno demais para virar hero.

Busque em inglês — o acervo é majoritariamente anglo. Para confecção têxtil funcionam:
`textile factory`, `sewing machine industrial`, `fabric rolls warehouse`, `denim fabric`,
`thread spools`, `clothing rack retail`, `knitted fabric texture`.

## Comprima antes de publicar

Foto de banco vem com 10-20 MB. Alvo: **menos de 1 MB para a página inteira** — quem abre
está no galpão ou na rua, com rede fraca.

```python
from PIL import Image
im = Image.open(src).convert("RGB")
im.thumbnail((1600, 1600))
im.save(dst, "JPEG", quality=72, optimize=True, progressive=True)
```

Cheque o tamanho de TODOS os arquivos depois de gerar. Um único JPEG de 20 MB que passou
despercebido domina o peso da página inteira e só aparece na hora da captura, quando o
render fica lento sem explicação.

## Aproveite a foto como fundo escuro

Foto de denim ou tecido escuro serve de hero com overlay e texto branco, sem precisar de
imagem extra. Componha o alpha antes de afirmar contraste: `rgba(255,255,255,.7)` sobre
foto clara não passa em WCAG mesmo parecendo legível no monitor.
