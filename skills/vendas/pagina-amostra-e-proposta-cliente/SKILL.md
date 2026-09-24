---
name: pagina-amostra-e-proposta-cliente
description: Use ao criar página de amostra e PDF de proposta ao cliente.
---

# Página de amostra (coringa) + proposta em PDF

Dispara em: "página de amostra", "page coringa", "modelo de site", "proposta pra
apresentar ao cliente", "PDF apresentando a página", "site pra vender pro lead".

Dois entregáveis que andam juntos: uma landing **modelo** que serve a vários clientes do
mesmo nicho trocando só um arquivo, e um **PDF** que a apresenta como proposta comercial.
É o passo seguinte da prospecção: a lista de leads mostra a dor, esta página é o produto.

Prazo típico do pedido é "hoje". Trabalhe direto no entregável final, não em rascunho.

## Regra central: o coringa é um arquivo de configuração

Todo conteúdo variável vive em UM `config.js` com comentários em português de leigo.
O HTML tem apenas âncoras (`data-bind="marca.nome"`, `data-lista="servicos"`) e o `app.js`
monta a partir do config. Cores saem como custom properties no `:root`.

```js
window.CONFIG = {
  marca:  { nome: "NOME DA FÁBRICA", cidade: "São Paulo", bairro: "Brás", desde: "1998" },
  cores:  { tinta: "#1a1a1a", destaque: "#c8452d" },
  galeria:{ fotos: [ { arq: "jeans.jpg", legenda: "Jeans" } ] },
  depoimento: { ativo: false }   // bloco some inteiro sem deixar buraco
};
```

Cada bloco opcional ganha um `ativo: true/false`. Listas controlam a QUANTIDADE de itens —
quatro serviços ou um, a página não pode quebrar. Isso é o que se vende na proposta,
então **prove que funciona** (ver Verificação).

## Procedimento

### 1. Descubra a marca antes de desenhar

Procure tokens/CSS do projeto do usuário no workspace. Se não houver, escolha direção
visual pelo COMPRADOR, não pelo gosto do momento: fábrica têxtil vende para dono de
marca, então editorial industrial e confiável — nada de estética de startup.

### 2. Consiga imagens reais e VALIDE cada uma

**Nunca escreva um ID de foto de banco de memória.** IDs lembrados retornam imagens de
assunto completamente diferente (pediu tear, veio café) e o erro só aparece quando o
cliente olha. Busque por API que devolva URL direta e valide o que baixou:

```python
# Openverse: API aberta, sem chave, licença comercial
"https://api.openverse.org/v1/images/?" + urlencode(
    {"q": q, "page_size": 15, "license_type": "commercial", "size": "large"})
```

Depois de baixar, passe CADA arquivo por `vision_analyze` perguntando o assunto e as
cores. Descarte o que não for do tema e o que for acervo histórico em P&B quando a
página precisa parecer atual. Detalhes e termos de busca: `references/imagens-para-landing.md`.

Comprima antes de usar: foto de banco vem com 20 MB e destrói o carregamento.
`Image.save(p, "JPEG", quality=72, optimize=True, progressive=True)`, alvo < 1 MB na
página inteira — quem abre está no galpão ou na rua, com rede fraca.

### 3. Construa e olhe de verdade

Sirva local (`python -m http.server`) e capture com Chrome headless. Receita de captura,
armadilhas de viewport e de medição: `references/captura-headless-chrome.md`.

A ordem que economiza horas: **meça primeiro, olhe depois**. `vision_analyze` julga bem
semântica (é a foto certa? o menu está duplicado? a imagem carregou?) e erra geometria
com convicção — ele afirma "letra cortada na borda" em recorte que o DOM prova íntegro.
Quando discordam sobre largura, posição ou corte, a medição do DOM decide.

### 4. Verificação — obrigatória nos dois entregáveis

**Comportamento:** teste real, não leitura de código. Monte a página num iframe e afirme
sobre o DOM montado — validação de formulário rejeitando campo vazio, mensagem do
WhatsApp montada, menu abrindo, `naturalWidth > 0` em toda imagem.

**O coringa:** duplique a página com um `config.js` alternativo (outra marca, outra cor,
outra quantidade de itens) e afirme que nome, `--destaque`, contagem de itens, título da
aba e telefone TODOS mudaram. Sem esse teste você está vendendo promessa não checada —
e as duas versões lado a lado viram a página mais forte do PDF.

Clonar o DOM já renderizado NÃO testa nada: o clone carrega o resultado do primeiro
config. Duplique o HTML apontando para o outro arquivo e carregue do zero.

**Números do PDF:** toda estatística citada precisa fechar aritmeticamente na cara do
leitor. Categorias que se sobrepõem produzem "117 + 28 + 23" que não soma o total e o
cliente nota. Recalcule da fonte e escolha um corte onde as partes somam o todo.

### 5. Entregue por caminho absoluto

A TUI não tem anexo. Diga o caminho do PDF e o da página, e diga que a página abre com
duplo clique (sem servidor). Limpe os arquivos de teste (`_*.png`, `_probe*.html`) antes
de fechar — mate o servidor local primeiro, senão o Windows recusa apagar com `WinError 32`.

Termine nomeando a decisão que falta (preço, logo), não com resumo do que foi feito.

## Escrita da página e do PDF (padrão do usuário)

Linguagem de leigo, teste de 5 segundos, zero jargão. O comprador de confecção decide por
três perguntas — **o que você produz, em quanto tempo, a partir de quantas peças** — e a
primeira tela responde as três.

- Sim: "Peça piloto em 7 dias, produção a partir de 50 peças por modelo."
- Não: "Soluções integradas em manufatura têxtil com excelência operacional."

No PDF: dor com consequência comercial colada e número verificado ao lado. Estrutura de
páginas, CSS de impressão e o que NÃO inventar: `references/proposta-pdf-cliente.md`.

No texto de amostra, evite placeholder que pareça descuido ("Trocar por fotos da sua
fábrica") — escreva a frase final plausível. O cliente lê a amostra como se fosse dele.

## Armadilhas

- **`hidden` perde para `display:flex`.** Bloco marcado `hidden` no HTML aparece no
  desktop se o CSS lhe dá `display`. Declare `display:none` no estado base e só ligue
  dentro do media query (`.menu-mobile:not([hidden]){display:flex}`).
- **Elemento posicionado com valor negativo vaza no mobile.** `right:-8px` num selo é
  charme no desktop e corte na tela de 390px. Reposicione dentro do media query.
- **Legenda sobre foto clara some.** Gradiente de `transparent` a preto não basta em foto
  de fundo branco: aumente a opacidade final e adicione `text-shadow`.
- **Separador `·` quebra linha feio no mobile.** Em texto curto que pode quebrar, prefira
  a conjunção ("Malha e básicos").
- **Não encerre por um único sinal visual.** Quando a imagem sugere defeito e a medição
  não confirma, investigue a captura antes de mexer no CSS — consertar layout são é o
  desperdício mais caro deste trabalho.

## Relacionadas

- `vendas/prospeccao-leads-locais` — de onde vem o cliente e a dor que a página resolve
- `dev/verificacao-de-tela-com-navegador` — diagnóstico de tela quando o check falha
