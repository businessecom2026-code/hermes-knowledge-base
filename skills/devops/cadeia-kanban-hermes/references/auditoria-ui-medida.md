# Auditar interface em produção por medição

Diagnóstico que origina os cards de UI. Vale para app logado, em navegador real.

## Semear dados antes de medir

**Tela vazia mente sobre o que o produto faz.** Tabela sem linhas não renderiza
checkbox de seleção, barra de ação em lote nem estado de hover — medir assim
produz o achado falso "não tem seleção múltipla" para um módulo que tem.

Antes de declarar que um recurso não existe, grepe o componente e as rotas:

```bash
grep -rnE "checkbox|selecionad|selection|bulk" src/components/*.tsx
ls apps/api/src/routes/ | grep -iE 'contact|financ'
```

Ausência na tela é hipótese; ausência no código é achado.

## Sessão é única por perfil de navegador — «ver como cliente» derruba o login

Botão de personificação («Ver demo do cliente», «entrar como», preview de
portal) troca o cookie de sessão **na mesma sessão do navegador**: o login real
do usuário é substituído, e o «sair da demo» que parece reverter desloga tudo.
Não abre aba isolada, por mais que o rótulo sugira.

Numa auditoria sobre o navegador do usuário isso custa o acesso dele e parece
defeito do produto. Regras:

- **Nunca clique em personificação numa sessão que não é sua.** Para medir o
  portal do cliente, peça uma aba/perfil separado ou delegue a um worker com
  seed próprio.
- Meça a conta **real** quando o achado for sobre ela: demo tem dados
  sintéticos e empresa fictícia, e concluir da demo sobre a conta do usuário é
  o erro que ele cobra depois. Diga explicitamente, no fechamento, qual das
  duas você mediu.
- Fixe o `targetId` **completo** da aba do usuário num ficheiro e reuse-o a cada
  chamada; truncar o id (ou redescobrir pela primeira aba) leva a medir a aba
  errada. Devolva `location` junto com cada leitura para confirmar.
- Restaure o estado que alterou (mês do calendário, filtro, aba) antes de
  entregar, e confirme por leitura — não por memória.

## Login wall: delegue a medição, não desista dela

O orquestrador não digita senha — nem a pede em conversa, nem a lê de arquivo.
Se o vault não tem item para a origem e o usuário recusa salvar, a verificação
visual **não é sua para fazer**. Não insista, e não conclua a auditoria com
«não deu para entrar».

Abra card de verificação visual para um worker: ele roda Playwright no repo real
com o seed de demonstração e alcança a tela. O que você não consegue medir por
restrição de credencial, um produtor mede — e volta com consola, DOM e os gestos
reproduzidos.

No corpo do card escreva o gesto exato a reproduzir (clique **e** atalho), o que
coletar (`[role="alert"]`, `aria-expanded`, se o POST sai, linhas da consola) e o
estado de dados necessário. Sem isso volta «testei, não funciona», que não
diagnostica nada.

## Toda medição devolve a identidade da tela que mediu

Número sem a rota ao lado é número órfão: parece plausível, entra no card, e
manda corrigir a página errada. Faça cada bloco retornar `location.hash` (ou
`pathname`) **na mesma chamada** que retorna o valor:

```js
(() => ({ rota: location.hash, vh: innerHeight, /* ...as medidas... */ }))()
```

Com `HashRouter`, navegar por URL a partir de uma página já aberta **não troca a
rota** — só o fragmento muda, o documento não recarrega, e você mede a tela
anterior. Troque pelo próprio router e espere o re-render:

```js
js("location.hash = '#/planos'")   // ~3s para montar
```

O sintoma de ter medido a tela errada imita defeito grave e convincente: vão
vertical enorme, elemento duplicado, bloco de outra página no meio. Quando a
medição acusar defeito espetacular numa página interna, **a primeira hipótese é
que você mediu a home**.

E rebuild antes de medir: o preview serve `dist/`, então medir sem reconstruir
mede a versão anterior e atribui ao produtor um defeito que ele já corrigiu.

## Trocar de idioma: imprima o texto renderizado como prova

Medir os quatro idiomas escrevendo o código no `localStorage` é o caminho certo,
e tem duas armadilhas que produzem **«tudo ok» silencioso e falso**: chave errada
(a escrita cria uma chave nova em vez de falhar) e código de locale abreviado
(`'pt'` onde a app usa `'pt-BR'`, e o seletor cai no default). Nos dois casos a
página nunca troca e você mede a mesma língua N vezes, concluindo que o idioma
mais longo cabe no layout quando nem chegou a ser renderizado.

Leia a chave e a união de locales da fonte antes de medir — nunca as adivinhe:

```bash
grep -nE "localStorage\.(get|set)Item|export type Lang" src/**/LanguageContext.tsx
```

E feche o buraco no método: **cada iteração imprime o título renderizado ao lado
do veredito**. O resultado só vale se os textos entre as iterações forem
diferentes; «ok» sem essa prova não é medição, é suposição com formato de tabela.

```js
({ lang: localStorage.getItem('<chave>'),
   titulo: document.querySelector('<sel>').textContent.trim().slice(0, 40),
   transborda: el.scrollWidth > el.clientWidth + 1 })
```

Depois de `location.reload()` o contexto de execução morre e o acesso seguinte ao
`localStorage` pode falhar por segurança; renavegue em vez de insistir. Em cena
WebGL, emular dispositivo com `deviceScaleFactor` 2–3 chega a estourar o tempo de
resposta do navegador — meça a 1, que a geometria de transbordo não depende da
densidade de pixel.

Texto denso em coluna estreita (`min(580px, 90vw)`) é onde copy nova quebra:
teste o idioma mais verboso do conjunto e confirme também
`document.documentElement.scrollWidth > innerWidth` — transbordo do elemento e
scroll horizontal da página são defeitos distintos.

## "Nada aparece acima da dobra" quase nunca é literal

A queixa útil não é que a tela está vazia — é que **o elemento que decide a
visita** está fora dela. Numa página de planos o card aparece e o preço não; num
catálogo aparece o título e não o produto. Meça as duas coisas separadamente:

```js
(() => {
  const alvo = [...document.querySelectorAll('*')].find(e =>
    e.children.length === 0 && /R\$|\d+\s*\/mês/.test(e.textContent || ''));
  const b = alvo && alvo.getBoundingClientRect();
  return { rota: location.hash, dobra: innerHeight,
           y_do_alvo: b && Math.round(b.y + scrollY),
           acima_da_dobra: !!b && (b.y + scrollY) < innerHeight };
})()
```

Escreva no card o **critério de aceite como invariante medida** ("primeiro valor
em dinheiro com y < 900 em 1440×900") em vez do meio ("reduza o vão"): o meio
prescreve solução a partir de um diagnóstico que pode estar errado, e o dono
rejeita layout comprimido tanto quanto layout vazio.

## Defeito de sobreposição é de camada, não de animação

Elemento decorativo 3D/canvas que cruza texto ou botão num breakpoint estreito,
e não cruza no largo, é posicionamento e empilhamento — não coreografia. Escreva
no card que a animação é intocável e que a correção é z-index, opacidade ou
deslocamento nesse breakpoint; sem isso o produtor "resolve" redesenhando o
movimento, que era justamente o que o dono pediu para preservar.

## Medir no DOM, não a olho

Colete números por JS e compare com invariantes, em vez de descrever impressão:
contagem de elementos com sombra, `cursor` computado em linha clicável, presença
de `transition`, altura do modal contra a altura do viewport, `autofocus`.

Modal mais alto que o viewport esconde o botão de salvar abaixo da dobra — meça
`getBoundingClientRect().height` do modal contra `innerHeight`, não role a tela
para ver se "dá para usar".

## Classe que depende de ancestral: a prova é no DOM, nunca no CSS compilado

`group-hover:*`, `peer-*` e afins geram um seletor que só casa se ALGUM ancestral
tiver a classe correspondente (`group`, `peer`). Falta o ancestral e o efeito
morre em silêncio: `tsc` e `eslint` não leem strings de classe, e a tela não
acusa nada — o hover apenas não acontece.

**Não tente provar isso comparando o CSS compilado.** A regra
`.group:hover .group-hover\:text-blue-400` nasce da classe do **filho**, então o
CSS sai idêntico com e sem o ancestral; um controlo que compare os dois passa
sempre, inclusive com o defeito presente, e você conclui que corrigiu sem ter
medido nada. O que muda é só quem ativa a regra — e isso vive no DOM renderizado.

A verificação que decide, no componente montado:

```js
[...container.querySelectorAll('[class*="group-hover:"]')]
  .filter(el => el.closest('.group') === null)   // tem de vir vazio
```

Feche com mutação na produção: remover a classe do ancestral tem de matar o
teste. Ao varrer a classe inteira do defeito (`grep -rl group-hover src`),
lembre-se de que o ancestral pode estar em qualquer altura da árvore — heurística
que procure `group` na mesma linha do filho produz falso positivo.

## Sem backend de pé, renderize o componente isolado em vez de desistir

Host sem banco nem API não impede medição visual: a demo pública falha, mas o
componente monta sozinho se a fronteira de I/O for substituída. Uma página de
preview temporária (entry HTML + um `.tsx` que importa o componente **real**) dá
pixel verdadeiro com dados fictícios.

**Intercepte na camada que o código usa, não na que você supõe.** Substituir
`window.fetch` não intercepta nada quando o serviço é axios — o adaptador de
browser do axios usa XMLHttpRequest. O sintoma imita defeito da app («não
consegui carregar» na tela) e faz perder rodadas a depurar componente são. Grepe
o serviço (`axios.create`, `fetch(`) antes de escrever o dublê; para axios, o
ponto certo é um interceptor que troca `config.adapter`.

O preview é andaime: apague-o antes de rodar os portões finais e confirme com
`git status --porcelain` — ficheiro esquecido na árvore é varrido por `tsc` e
`eslint` e derruba o portão dos irmãos.

## Data-only exibida um dia atrás: prove o fuso no próprio navegador

Data sem hora (`dueAt`, `entryDate`) chega como meia-noite UTC. Renderizada com
`toLocaleDateString` sem `timeZone`, o navegador converte para o fuso local e
qualquer offset negativo (Brasil, Américas) **volta um dia**: 15/10 vira 14/10.
O defeito não aparece para quem desenvolve em UTC ou a leste de Greenwich.

A prova mais barata não precisa da API nem de semear dado — roda no console da
sessão do próprio usuário e compara as duas formas lado a lado:

```js
(() => { const d = '2026-09-23T00:00:00.000Z';
  return { fuso: Intl.DateTimeFormat().resolvedOptions().timeZone,
           SEM_fix: new Date(d).toLocaleDateString('pt-BR', {day:'2-digit', month:'2-digit'}),
           COM_fix: new Date(d).toLocaleDateString('pt-BR', {day:'2-digit', month:'2-digit', timeZone:'UTC'}) };
})()
```

Divergir entre os dois campos confirma que o fuso do navegador reproduz o bug;
bater com o que a tela mostra confirma qual das duas versões está publicada.
A correção é `timeZone: 'UTC'` em **todo** render de data-only — grepe a classe
(`grep -rn "toLocaleDateString" src/`), porque calendário, tabela e cards de
resumo costumam formatar cada um por sua conta e só um foi corrigido.

Confirme em telas independentes: tabela, calendário e card de resumo a mostrarem
o mesmo dia é o aceite; uma delas divergir indica formatador esquecido.

## Contraste: componha a PILHA de fundos antes de acreditar no número

Razão de contraste calculada com `backgroundColor` lido direto trata
`rgba(239,68,68,0.06)` como opaco e devolve valor gravemente errado — mediu 1.98
onde o real era 10.25. Empilhe os fundos do elemento até à raiz, componha cada
camada sobre a anterior e só então calcule a luminância. Sem isso o achado que
você repassa é pior que nenhum: manda corrigir cor que já passa com folga.

**Parar no primeiro fundo não-transparente tem o mesmo efeito e esconde-se
melhor.** Um `rgba(255,255,255,0.05)` de hover vira branco opaco, e texto claro
sobre ele reporta razão 1.00. Numa varredura real isso inflou 27 reprovações
para 62. Continue subindo até `a === 1`, acumule e componha de trás para a
frente:

```js
function fundoReal(el) {
  const pilha = []; let p = el;
  while (p) { const c = rgba(getComputedStyle(p).backgroundColor);
    if (c && c.a > 0) { pilha.push(c); if (c.a === 1) break; }
    p = p.parentElement; }
  let base = pilha[pilha.length - 1] || {r:255,g:255,b:255};
  for (let i = pilha.length - 2; i >= 0; i--) { const f = pilha[i];
    base = { r: f.r*f.a + base.r*(1-f.a),
             g: f.g*f.a + base.g*(1-f.a),
             b: f.b*f.a + base.b*(1-f.a) }; }
  return base;
}
```

**Razão exatamente 1.00 é sinal de medidor quebrado, não de defeito** — cor de
texto igual ao fundo computado significa comparar um valor consigo mesmo.
Agrupe o resultado por `cor|razão` antes de repassar: reprovação real colapsa em
poucas causas (quatro tokens explicaram 27 ocorrências), enquanto ruído de
medição se espalha em cores sem relação. O agrupamento também dá ao produtor o
que corrigir — token, não lista de elementos.

Meça **nos dois temas**: a mesma cor dá 7.2 no claro e 4.0 no escuro, e auditar
só um deles esconde metade dos defeitos.

Depois de medir, verifique se o defeito é da entrega ou da convenção do projeto
antes de reprovar. `git diff --stat HEAD -- <ficheiro>` vazio e contagem do token
idêntica à do `HEAD` provam herança; token presente em dezenas de ficheiros é
decisão de design system e merece card próprio, não reprovação de quem mexeu no
layout ao lado.

## Nome acessível: `textContent`, nunca `innerText`

`innerText` devolve apenas texto **renderizado**: dentro de `<details>` fechado,
`hidden`, ou qualquer ancestral com `display:none`, vem vazio. Varrer botões com
ele produz o achado falso "N botões sem rótulo acessível" para botões que têm
texto — num calendário com dias colapsados deu 10 falsos positivos, todos com a
mesma classe, o que ainda sugere convincentemente uma causa única no código.

Um leitor de tela lê a árvore de acessibilidade, não o que está visível. Meça as
quatro fontes de nome:

```js
const nome = (b.getAttribute('aria-label') || '').trim()
          || (b.textContent || '').trim()        // não innerText
          || (b.getAttribute('title') || '').trim()
          || (document.getElementById(b.getAttribute('aria-labelledby') || '')?.textContent || '').trim();
```

O mesmo vale para campo de formulário: antes de reportar `input` sem rótulo,
teste `el.closest('label')` — rótulo envolvente é válido e dispensa `for`/`id`.

Achado de acessibilidade falso custa mais caro que a maioria: manda corrigir
código são e gasta uma cadeia inteira. Antes de repassar, abra **um** caso na
fonte e confirme que o rótulo realmente não existe.

## Geometria de SVG desenhado à mão

Filtre os gráficos pelo `viewBox` antes de medir, senão a query pega os ícones:

```js
const svgs = [...document.querySelectorAll('svg')]
  .filter(s => (s.getAttribute('viewBox') || '').includes('480'));
```

### Invariante de contenção

Nenhum elemento pode sair da moldura, para qualquer entrada:

```js
const vb = svg.viewBox.baseVal;
[...svg.querySelectorAll('rect')].map(r => ({
  y: +r.getAttribute('y'),
  foraDeCima: +r.getAttribute('y') < 0,
  foraDeBaixo: (+r.getAttribute('y')) + (+r.getAttribute('height')) > vb.height,
}));
```

`y` negativo significa barra cortada no topo. A causa recorrente é **domínio da
escala derivado de valores diferentes dos que são plotados**: escala montada
sobre o valor bruto negativo e barra desenhada com `Math.abs(valor)`, que cai
fora do domínio. A correção é recalcular o domínio sobre os valores efetivamente
desenhados — não remover o `Math.abs`, que costuma existir porque o rótulo já
carrega a direção.

Reproduza a aritmética da escala fora do navegador com os valores reais da tela
antes de abrir o card: confirma a causa e dá o número exato que o teste deve
reproduzir.

### Texto de eixo encolhe com o container

`font-size` dentro de SVG é em unidades de viewBox. O tamanho real é:

```js
const escala = svg.getBoundingClientRect().width / svg.viewBox.baseVal.width;
const realPx = +(t.getAttribute('font-size') * escala).toFixed(1);
```

Um `font-size="11"` num viewBox de 480 renderizado a 318px vira **7,3px**. Alvo:
nunca abaixo de 11px reais. Medir em pelo menos três larguras de janela — só
aumentar o número do atributo conserta o container estreito e estoura o largo.

### Procurar NaN

```js
[...svg.querySelectorAll('*')].filter(e =>
  [...e.attributes].some(a => a.value.includes('NaN')));
```

Tem de vir vazio. `NaN` em atributo produz gráfico em branco sem mensagem de
erro — falha que passa por "sem dados".

## Validação nativa do navegador aborta submit em campo escondido

Campo `required` dentro de container com `display:none` (a classe `hidden` do
Tailwind) não é focável, e o Chrome **recusa validar controlo não-focável**:
escreve `An invalid form control with name='X' is not focusable` na consola e
aborta a submissão inteira. O sintoma na tela é o pior possível — carregar em
Salvar não produz erro, não produz gravação, não produz nada.

Isso atinge qualquer caminho que passe por `requestSubmit()`: botão, atalho de
teclado, retry programático. Antes de culpar o handler de submit ou o hook de
atalho, **abra a consola e procure `is not focusable`**.

A correção fica no lado do `required` (condicional à secção estar aberta) ou na
forma de esconder (fora do fluxo, mas focável) — não em «ligar o handler», que
nessa altura já está ligado e correto.

Gaveta/acordeão com campo obrigatório dentro é o caso recorrente: escreva no card
que o handler de `onInvalidCapture` existe e onde, para o produtor não reimplementar.

## Não trocar correção por biblioteca

Gráfico em SVG à mão costuma ser decisão do projeto. Adicionar uma lib de
gráfico não corrige erro de escala nem de legibilidade e infla o bundle —
escreva no card que a lib é reprovação e confira `package.json` na revisão.

## Preservar a via não-visual

Quando o SVG é `aria-hidden` de propósito, a tabela equivalente é a única via de
acesso ao dado. Qualquer mudança no gráfico precisa manter a tabela dizendo tudo
que o gráfico diz.

## Gráfico bonito com escala errada é pior que gráfico quebrado

O cortado o usuário percebe; o incoerente ele acredita. Se a geometria não foi
provada por medição, não aceite — e escreva isso no card do confirmador.
