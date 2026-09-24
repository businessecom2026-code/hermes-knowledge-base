# Captura headless com Chrome (screenshot e PDF)

Quando a captura precisa ser determinística — página inteira, PDF, várias larguras em
sequência — chame o Chrome direto. Não depende de estado de aba e cada invocação é isolada.

```bash
CH="C:/Program Files/Google/Chrome/Application/chrome.exe"

# screenshot de página inteira, 2x
"$CH" --headless=new --disable-gpu --user-data-dir="$TMP/ch" --hide-scrollbars \
  --force-device-scale-factor=2 --window-size=1440,4400 \
  --virtual-time-budget=14000 --screenshot=out.png "$URL"

# PDF A4 sem cabeçalho/rodapé do navegador
"$CH" --headless=new --disable-gpu --user-data-dir="$TMP/ch" \
  --virtual-time-budget=20000 --no-pdf-header-footer --print-to-pdf=out.pdf "$URL"
```

- `--virtual-time-budget` é **obrigatório** em página que monta por JS: sem ele a captura
  sai antes do script rodar e o PNG vem vazio.
- `--user-data-dir` num temporário, nunca o perfil do usuário.
- Sirva por `http://127.0.0.1:<porta>` (`python -m http.server`) quando a página buscar
  recursos; `file://` basta para a entrega final ao cliente, mas complica a captura.

## `--window-size` não é a viewport

O Chrome headless pode renderizar numa largura e recortar o PNG noutra: pedir
`--window-size=390` e ver `innerWidth === 500` com a imagem cortada em 390 produz um
"texto cortado na borda direita" que **não existe na página**. Antes de mexer no CSS,
confirme `innerWidth` na sonda.

Para capturar uma largura exata, envolva a página num wrapper com iframe fixo e fotografe
o wrapper:

```html
<body style="margin:0;width:390px">
<iframe src="index.html" scrolling="no"
        style="display:block;width:390px;height:5400px;border:0"></iframe>
</body>
```

## `--dump-dom` fotografa ANTES do JS montar

`--dump-dom` devolve o HTML quase cru: numa página que injeta seções via JS, as listas
aparecem vazias e a leitura ingênua conclui "a página não monta". Não é bug da página.

Para ler estado pós-render sem depender do daemon do browser, injete uma sonda que escreve
o resultado num `<pre>` e leia esse `<pre>` do `--dump-dom`:

```html
<pre id="__t"></pre>
<script>addEventListener('load',function(){setTimeout(function(){
  document.getElementById('__t').textContent =
    'w=' + innerWidth +
    ' itens=' + document.querySelectorAll('.item').length +
    ' imgs_ok=' + [].slice.call(document.images).filter(i=>i.naturalWidth>0).length +
    ' overflow=' + (document.documentElement.scrollWidth > document.documentElement.clientWidth);
},3000)});</script>
```

## `naturalWidth` mente com lazy loading

Imagem `loading="lazy"` fora da viewport reporta `naturalWidth === 0` e o teste conclui
que a imagem quebrou. Force `loading="eager"` na sonda de captura ou role a página até o
fim antes de medir.

## Recorte de seções para o PDF

Tire UMA captura de página inteira em 2x e recorte as seções com Pillow, em vez de uma
captura por seção. Cada invocação do Chrome custa segundos e pode pegar a página num
estado de scroll diferente; um único PNG garante consistência visual entre as páginas do PDF.

```python
Im.open("full.png").crop((0, y0*2, W*2, y1*2)).save("secao.png")  # *2 = device scale
```

Pegue os `y` reais medindo `getBoundingClientRect().top + scrollY` de cada `<section>`,
não a olho.

## Limpeza no Windows

Mate o `http.server` e espere o Chrome encerrar antes de apagar os temporários: processo
segurando o arquivo faz o `unlink` falhar com `WinError 32` (arquivo em uso). Se ainda
assim travar, deixe o temporário — não vale reiniciar processo do usuário por isso.

## Validação do PDF gerado

`pymupdf` (instale com `uv pip install pymupdf` no interpretador do Hermes) responde o que
importa sem abrir o arquivo na mão:

```python
import pymupdf
d = pymupdf.open(p)
len(d)                                   # número de páginas bate com o planejado?
d[0].rect                                # A4 = 595 x 842 pt
len(d[0].get_images())                   # 0 numa página que devia ter mockup = imagem não entrou
"".join(pg.get_text() for pg in d)       # confira cada número citado
d[0].get_pixmap(dpi=105).save("p1.png")  # e olhe a página renderizada
```

Página com 0 imagens quando devia ter mockup normalmente é caminho relativo quebrado no
HTML de impressão — use caminho absoluto `file:///` ou base64 embutido.
