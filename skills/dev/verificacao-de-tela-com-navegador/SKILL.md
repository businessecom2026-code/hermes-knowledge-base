---
name: verificacao-de-tela-com-navegador
description: Use ao corrigir check de tela que falha.
---

# Verificação de tela com navegador

## Sobreposição: descarte os filhos do próprio elemento sobreposto

Ao medir se uma faixa (cookie, toast, dock) cobre conteúdo, um teste ingênuo de
intersecção de retângulos acusa os **botões da própria faixa** como "texto coberto" —
"Aceitar", "Recusar", "Política de privacidade". Num caso real, 4 supostos elementos
cobertos eram 3 filhos da faixa e só 1 conteúdo verdadeiro.

Filtre com `faixa.contains(el)` antes de contar, e confirme o impacto clicando
"Aceitar": se a faixa some e o conteúdo reaparece, é ressalva dispensável, não defeito.

## WebGL: `toDataURL` mente quando `preserveDrawingBuffer` é false

Para provar que uma cena 3D anima, **leia antes** `canvas.getContext('webgl2').getContextAttributes().preserveDrawingBuffer`. Quando é `false` (o padrão, e o que three.js/R3F usam), o buffer é descartado após o compositor consumir o frame: `toDataURL()` fora do `requestAnimationFrame` devolve buffer limpo e **duas leituras batem sempre**, mesmo a 60fps. Isso já produziu uma reprovação falsa de "animação travada".

`readPixels` dentro do rAF tampouco basta: amostrar o canto (0,0) devolveu `brilho: 0` em todas as posições porque aquele canto é fundo preto.

Método confiável: **`Page.captureScreenshot` do CDP** (composto, é o que o olho vê), recortado na área do canvas via `getBoundingClientRect()` × `devicePixelRatio`, comparado pixel a pixel com PIL e tolerância de ~8 níveis por canal.

**Sempre meça um controle**: dois frames na MESMA posição de rolagem. Se der 0% ali, o método está cego — não a cena. Numa esfera girando sozinha o controle deu 3,49%, e a rolagem 15%→22% deu 20,94%.

## Texto dividido entre filhos: leia `innerText` do container

Varrer só nós-folha (`el.children.length === 0`) devolve lista vazia quando o texto
está repartido entre elementos filhos — ex.: um preço com valor e legenda em `<span>`
separados. O resultado parece "não existe na página" quando existe.

Antes de concluir ausência, confirme pelo texto renderizado do bloco:

```js
document.body.innerText.includes('Sob Consulta')   // acha o que a varredura de folhas perdeu
```

Só então localize o elemento e meça a caixa.

## Aba headless suspensa congela RAF e IntersectionObserver

Antes de medir qualquer coisa animada (canvas, WebGL, ScrollTrigger, IO),
cheque `document.visibilityState`. O browser headless costuma abrir a aba em
background: o Chrome congela `requestAnimationFrame` e `IntersectionObserver`,
e todo canvas animado le 0 pixels. Parece bug do site e nao e.

Destrave no inicio da medicao (`Page.bringToFront` NAO resolve sozinho):

    cdp('Emulation.setFocusEmulationEnabled', enabled=True)
    cdp('Page.setWebLifecycleState', state='active')

Valide contando frames (esperado >0 em 2s):

    js("(() => { window.__f=0; const t=()=>{window.__f++; requestAnimationFrame(t);}; requestAnimationFrame(t); })()")
    # time.sleep(2); js("window.__f")

## Amostrar canvas: repita a leitura antes de acreditar num salto

Uma leitura unica de `getImageData` pode cair entre o `clearRect` e o desenho
do quadro e retornar quase zero, gerando falso "salto" na curva. Leia a MESMA
posicao 4-5 vezes com ~0.7s de intervalo; so trate como descontinuidade real
se as repeticoes concordarem.

## Nao recarregue a pagina no meio de uma medicao instrumentada

Hooks injetados em `window` ou no ctx do canvas morrem no reload. Faca setup,
scroll e leitura na MESMA chamada. Com Lenis, `window.lenis` pode ser apenas
`{version}` e nao a instancia: teste `typeof l.scrollTo === 'function'` antes
de usar, com `window.scrollTo` como fallback.

## Olhe a tela antes de medir números

Métricas (FPS, altura de scroll, opacidade computada) não revelam defeito visual. Um site pode marcar 60fps com um losango branco torto à volta de cada ícone e texto rodado 90°. Capture screenshot e passe por `vision_analyze` ANTES de concluir que "está sólido": a descrição em linguagem natural encontra em uma passagem o que dez medições numéricas não mostram.

## Nunca esconda overlays com seletor por substring de classe

`[class*=consent]` e `[class*=cookie]` atingem containers genéricos do app (uma `<div>` raiz com `class="...consent-wrapper..."` ou qualquer utilitário que contenha a substring) e aplicam `display:none` no site inteiro. O sintoma engana: `body.scrollHeight === 0`, todos os `[data-reveal]` presos em `opacity:0`, e a conclusão errada de que o scroll reveal está quebrado.

Esconda pelo TEXTO do elemento e confirme a altura do body depois:

```js
[...document.querySelectorAll('div,section,aside')].forEach(e => {
  if (/Usamos cookies/i.test(e.innerText||'') && e.children.length < 10) e.style.display='none';
});
// obrigatório: se body.scrollHeight caiu para 0, você apagou o app
```

## Variável CSS escrita por rAF só existe depois de frames reais

`window.scrollTo(y)` seguido de leitura imediata devolve o valor ANTERIOR (quase sempre 0) para qualquer `--var` que a coreografia escreve em `requestAnimationFrame`. Conclusão falsa: "a cena está parada". Espere 3 frames encadeados entre mover e ler:

```js
window.scrollTo(0, y);
requestAnimationFrame(()=>requestAnimationFrame(()=>requestAnimationFrame(()=>{ /* ler aqui */ })));
```

E quando o DOM parece imóvel numa experiência WebGL, compare PIXELS do canvas (`drawImage` num canvas 48×48 + `getImageData`, diferença entre amostras) antes de dizer que nada acontece — o movimento pode estar todo na GPU.

## Colisão de nome de classe entre página e experiência

Antes de criar uma classe `.e360-algo` (ou qualquer prefixo compartilhado) numa página nova, procure o nome no projeto inteiro. Reusar uma classe que a home já define faz a nova herdar `position:absolute`, `writing-mode:vertical-rl` e afins — o texto renderiza em coluna e a descrição fica com altura 0. Quando `getComputedStyle` mostra um valor que nenhuma regra explica, suba a árvore com `parentElement` lendo o computado de cada nível: a origem é herança de um ancestral homônimo.

## Recuperação do daemon do browser

`Runtime.evaluate timed out` ou `WinError 2 ... could not be started` costuma resolver com `ensure_real_tab()` seguido de `goto_url(...)`. Não reinicie o preview nem refaça o build por isso; e faça a navegação e as leituras dependentes NO MESMO bloco, porque entre chamadas a aba pode ter sido recriada em `about:blank`.

## Medir alvo de toque em link inline dá falso negativo

`getBoundingClientRect().height` num `<a>` inline devolve a altura da caixa
colapsada, não a área clicável — um link com `min-height: 44px` aplicado e
verificado no computed style ainda aparece como 19px. Meça com
`Math.max(...[...el.getClientRects()].map(r => r.height))` e confirme sempre o
`getComputedStyle(el).minHeight` antes de concluir que a regra não aplicou.
Sem isso, você reescreve CSS que já estava correto.

## Zero pode ser página morta, não aprovação

Um servidor de preview que caiu no meio da bateria devolve DOM vazio, e toda
contagem de defeito dá **zero** — indistinguível de "tudo corrigido". Antes de
aceitar qualquer zero, conte o universo medido e retorne junto:

```js
const alvos = [...document.querySelectorAll('a,button')].filter(e => e.getBoundingClientRect().width > 0).length;
// alvos === 0  ->  medição inválida, não aprovação
```

Um `curl -o /dev/null -w '%{http_code}'` antes da sessão pega servidor caído
(HTTP 000), mas não pega a queda no meio — só a contagem pega.

## Asserção de ambiente na MESMA chamada que mede

`Emulation.setDeviceMetricsOverride` e `location.hash` assentam de forma
assíncrona, com atraso típico de uma chamada. Pedir 375px e medir na chamada
seguinte devolve a largura anterior: você mede o desktop achando que é telefone
e vê "29 falhas de alvo de toque" que são alvos corretos na largura errada.

Retorne o ambiente junto com o número, no mesmo `js()`, e descarte se não bater:

```js
return {iw: innerWidth, rota: location.hash, n: falhas.length, alvos: n_alvos};
// Python: if r['iw'] != largura_pedida or r['rota'] != rota: descartar e repetir
```

`time.sleep()` sozinho não sincroniza override de viewport.

## Confirme o tipo de router antes de navegar por URL

Com `HashRouter`, `http://host/servicos` devolve HTTP 200 servindo a home — a
página monta, nada dá erro, e o teste conclui que a rota está quebrada. Cheque
`grep -n 'HashRouter\|BrowserRouter' App.tsx` e use `#/rota` quando for hash.

## Contraste: componha o alpha antes de calcular

Cor de texto em `rgba(..., 0.66)` sobre fundo escuro não tem o contraste do
RGB puro. Componha sobre o fundo (`fg*a + bg*(1-a)`) antes da razão WCAG;
ignorar o alpha devolve o mesmo valor para todos os textos, que é o sinal de
que a medição está errada.

Use ao verificar erros de UI reportados, corrigir checks de tela (Playwright) que falham após redesign, ou investigar tela branca em React.

Quando um check de tela falha, há SEMPRE duas hipóteses, e elas pedem ações opostas:

| Hipótese | Sinal | Ação |
|---|---|---|
| Bug real no produto | `pageerror` no console, `#root` vazio, dado errado | Corrigir o **código**, escrever teste de regressão |
| Asserção obsoleta | Tela renderiza bem, só o seletor não casa | Corrigir o **check**, citando a decisão de design |

**Nunca mude o check antes de provar que não é bug.** Um check enfraquecido para ficar verde é pior do que um check vermelho: some com o sinal.

## O ciclo que funciona

1. **Reproduza isolado.** Escreva um `diag-tmp.mjs` que monta só o componente com o mesmo harness do check. Apague-o no fim.
2. **Escute `pageerror` SEMPRE.** `p.on('pageerror', e => console.log(e.message, e.stack))`. Sem isso, tela branca é indistinguível de seletor errado.
3. **Pergunte ao DOM, não adivinhe.** Liste os rótulos/botões reais em vez de tentar variações do seletor:
   ```js
   await p.locator('button:visible').allInnerTexts()
   await p.locator('label').allInnerTexts()
   ```
   Cada palpite custa um ciclo de 3 minutos; uma listagem resolve todos.
4. **Se renderiza bem, procure a decisão de design.** `git log -S "<texto>"`, comentários no componente, `docs/`. O código deste projeto explica as mudanças em comentário — leia antes de reescrever.
5. **Ao corrigir o check, escreva o PORQUÊ no comentário**, com data e a razão do desenho. O próximo a ver isto precisa saber que foi deliberado.

## Armadilhas que já custaram tempo aqui

- **`127.0.0.1` ≠ `localhost`.** Vite sem `--host 127.0.0.1` escuta só em `::1`; o check bate em `127.0.0.1` e leva `ECONNREFUSED`. Suba com `vite --port <p> --strictPort --host 127.0.0.1`.
- **DOIS Vite na mesma porta** — sim, acontece apesar de `--strictPort`, quando um segundo arranca antes de o primeiro largar a porta. Sintoma típico: `useX must be used inside <XProvider>` num harness que claramente envolve o Provider. Causa: o componente vem servido com `?t=<timestamp>` de HMR e o harness importa sem o sufixo — são **dois módulos**, logo dois contextos. Diagnostique e resolva assim:
  ```bash
  netstat -ano | grep ':4191' | grep LISTENING | awk '{print $5}' | sort -u   # >1 PID = duelo
  curl -s http://127.0.0.1:4191/src/components/X.tsx | grep -oE 'from "[^"]*Context[^"]*"'  # tem ?t= ?
  ```
  Mate TODOS os PIDs e suba um só com `--force` (reotimiza os deps). Nunca "conserte" o check por causa disto: o produto está são.
- **Proxy do Vite fura os mocks.** `vite.config.ts` costuma ter `proxy: { '/api': 'localhost:3001' }`. Com a API local a correr, `page.route('**/api/**')` continua a valer, mas qualquer pedido não interceptado chega à base de dados real e os dados não batem com o esperado. Pare a API antes de correr checks com mocks.
- **Modal antigo continua montado.** `getByRole('dialog')` sem nome apanha o primeiro (oculto). Use `getByRole('dialog', { name: '<título>' })`.
- **Dois botões com o mesmo nome** (barra + estado vazio) quebram o strict mode: `.first()`.
- **Menu flutuante fecha a qualquer rolagem.** Playwright rola antes de clicar. Assente a página primeiro: `scrollIntoViewIfNeeded()` na linha, `waitForTimeout` curto, e só então abra.
- **Campo invisível pode estar numa gaveta recolhida.** Suba a árvore do elemento e veja quem tem `display:none`:
  ```js
  el.evaluate(e => { for (let n=e; n; n=n.parentElement) if (getComputedStyle(n).display==='none') return n.className; })
  ```
- **Sem o CSS real o bug não aparece.** Importe `/src/index.css` no harness, senão gavetas fechadas renderizam abertas e o diagnóstico mente.
- **Coluna some por viewport, não por bug.** `hidden xl:table-cell` sai abaixo de 1280px. Condicione a asserção à largura.
- **Harness monta o filho sem a moldura.** O `<h1>` costuma viver no dashboard, não no componente. Afirme pelo conteúdo da lista, não pelo heading da página.

## Tela branca em React: a causa é quase sempre a mesma

Duas faltas irmãs, ambas fatais para a tela inteira:

```js
dados?.catalogs.chartAccounts   // ✗ `?.` só no 1º nível; `catalogs` ausente rebenta
dados?.catalogs?.chartAccounts ?? []   // ✓ opcional em todos os níveis, até o `??`

setHistorico(r.data.events)        // ✗ resposta sem `events` põe `undefined` no estado
setHistorico(r.data.events ?? [])  // ✓ `useState<T[]>([])` promete lista ao render
```

Um `.catch` ao lado NÃO cobre o segundo caso: ele apanha a rede, não a resposta bem-sucedida e vazia. Dois caminhos reais levam lá — corpo antigo em cache de service worker (PWA) e resposta parcial durante deploy.

Ao achar uma, **varra a classe inteira** antes de fechar:
```bash
grep -rnE "(dados|data|resumo)\?\.[a-zA-Z]+\.[a-zA-Z]" apps/web/src/components/
grep -rnE "set[A-Z][a-zA-Z]*\(r\.data\.[a-zA-Z]+\)" apps/web/src/components/
```

## Teste de regressão que vale a pena

Neste repo a convenção é ler o fonte e afirmar sobre ele (`readFileSync` + regex), com o cabeçalho a contar o sintoma observado. **Prove que o teste pega o bug**: reintroduza o defeito com `sed`, veja falhar, restaure, veja passar. Teste que nunca falhou não prova nada.

## Antipadrões

- Enfraquecer asserção (`count()` → `.first()`, exato → regex frouxa) sem ter olhado a tela
- Apagar uma asserção porque "o design mudou", sem confirmar no `git log` ou nos comentários
- Palpitar seletores em série em vez de listar o DOM uma vez
- Deixar `diag*-tmp.mjs` no repo

## Erro em log não é avaria até prova em contrário

Um `Error` no log de um serviço externo (WhatsApp/Baileys, Stripe, e-mail) costuma ser o tratamento a funcionar, não a falhar. Antes de "corrigir":

1. **Ache o handler** desse evento e leia o ramo de erro inteiro.
2. **Pergunte o que o código faz a seguir.** Há espera crescente? Teto de tentativas? Estado persistido para a tela poder contar? Saída limpa quando não se deve reconectar?
3. **Se o tratamento existe e está certo, o trabalho é de TESTE, não de código.** Um refactor futuro pode transformar backoff em ciclo fechado — contra um serviço externo isso custa bloqueio do número/conta.

O que trancar num serviço com reconexão: crescimento do intervalo **e** teto; limite de tentativas; estado de falha persistido; sucesso a limpar o contador; logout a NÃO reconectar; handler `async` de evento com `try/catch` (exceção ali é promessa sem dono e mata o processo).

## Relacionadas

- `dev/diagnosing-bugs` — laço de diagnóstico para bugs difíceis
- `dev/code-review` — revisão das mudanças

## Confirmar que a correção chegou à produção

Build local verde não prova deploy. Depois do push, confirme no que o navegador executa:

1. **A branch chega à produção?** Publicar numa branch de release NÃO faz deploy se o serviço segue a `main`. Confira `git symbolic-ref refs/remotes/origin/HEAD` e, se preciso, `git merge --ff-only` para a branch padrão.
2. **O bundle mudou?** `curl -s <url> | grep -oE 'assets/index-[A-Za-z0-9_-]+\.js'` antes e depois. Hash igual = deploy não rodou.
3. **O hash local NÃO bate com o de produção** — e isso é normal: o CI reconstrói com deps de produção. Nunca compare hashes; compare **conteúdo**.
4. **Procure a correção no chunk certo.** O `index-*.js` costuma só arrancar a app; as telas vão em chunks lazy. Ache o nome dentro do bundle de entrada e baixe esse.
5. **Busque a forma minificada**, não o fonte: `x ?? []` vira `x??[]`, e `a?.b` vira `(a)==null?void 0:a.b`.
   ```bash
   grep -cE 'events\?\?\[\]|events \?\? \[\]' prod-chunk.js
   grep -coE '\.catalogs\)==null\?void 0:|catalogs\?\.' prod-chunk.js
   ```
6. **Abra a tela** e confirme `#root` preenchido — o health check responde 200 com a SPA em branco.

PWA agrava: o service worker serve o bundle velho. Validar com `Cache-Control: no-cache` e, na dúvida, janela anónima.
