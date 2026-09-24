# Efeitos de motion e 3D que realmente acontecem

O modo de falha dominante neste projeto não é efeito que quebra: é efeito que
**compila, roda todo frame e não produz pixel nenhum**. `tsc` verde, `npm run
build` verde, `EffectComposer` instanciado, hook montado — e a tela idêntica.
Nenhum portão estático pega isso. Só medição no navegador pega.

Este arquivo reúne as armadilhas que já custaram retrabalho e o modo de provar
que o efeito existe.

## Provar antes de declarar pronto

A prova aceitável é **número que muda no tempo**, não presença de símbolo no DOM.

```js
// amostra o transform a cada 100ms durante a transicao
(() => new Promise(res => {
  const a = [];
  const t0 = performance.now();
  const id = setInterval(() => {
    const w = document.querySelector('[data-line-reveal] .e360-word');
    if (w) {
      const m = getComputedStyle(w).transform;
      a.push(m === 'none' ? 0 : +parseFloat(m.split(',')[5] || 0).toFixed(1));
    }
    if (performance.now() - t0 > 1600) { clearInterval(id); res(JSON.stringify(a)); }
  }, 100);
}))()
// 37.9 -> 21.5 -> 8.6 -> 3.4 -> 1.1 -> 0.2 -> 0   = anima e desacelera (power4.out)
// [0,0,0,0,...]                                   = o hook existe e nao anima
```

A curva desacelerando prova o easing junto. Uma única leitura depois do repouso
não distingue «animou e chegou» de «nunca saiu do lugar» — amostre durante.

Cinco armadilhas tornam a medição falsamente negativa. Todas já produziram o
veredito errado aqui:

- **`once: true` dispara uma vez por carregamento.** Percorrer a página medindo
  vários elementos numa só passagem devolve `0` em todos os que já animaram, e
  parece que nada funciona. Recarregue a página por elemento medido.
- **Smooth scroll interpola o `scrollTo`.** Com Lenis no comando, `scrollTo(0,Y)`
  não coloca a página em `Y` imediatamente — pedir 4208 e medir logo a seguir lê
  a página em 2859, antes do gatilho. Espere `scrollY` estabilizar (ler em laço
  até repetir o valor) antes de amostrar.
- **`requestAnimationFrame` não corre em aba sem foco** e a série volta vazia.
  Meça com `setInterval(...,16)`, que corre independentemente do foco.
- **Cada chamada de avaliação JS é um contexto novo:** `window.__rec` gravado
  numa chamada não existe na seguinte. O gravador e a leitura têm de estar na
  MESMA expressão.
- **A ponte CDP corta expressões longas em poucos segundos.** Uma descida
  completa da página não cabe numa avaliação; posicione antes do gatilho numa
  chamada, e grave a janela curta da transição noutra.
- **Emular telemóvel com `deviceScaleFactor` 2 ou 3 satura o renderizador.** A
  cena passa a desenhar 4× a 9× mais pixels, as avaliações excedem o tempo da
  ponte e a sessão morre a meio do laço. Meça com escala `1` — medida de layout
  é em CSS pixels e não muda com a escala. Limpe com
  `Emulation.clearDeviceMetricsOverride`, que sobrevive à navegação.
- **`location.reload()` invalida o contexto:** a avaliação seguinte pode falhar
  com `SecurityError` ao tocar `localStorage`. Não é permissão negada — é
  contexto morto. Renavegue em vez de encadear reloads.

A amostragem também responde a uma pergunta que o olho não responde: **qual é o
estado final**. Valor diferente de zero depois de a transição terminar não é
«animação em curso», é elemento que ficou escondido — ver a armadilha do
`gsap.from` abaixo.

Para efeito de imagem (bloom, glow, blur), a prova é captura + comparação
explícita: pergunte se há **halo difuso ao redor dos traços** ou linhas secas.
«Parece brilhante» é enganoso aqui: o fundo desta home tem bokeh verde, e ele dá
a impressão de glow atrás de um wireframe completamente seco.

## Higiene da captura: o screenshot que você analisa tem de ser o desta medição

`capture_screenshot()` reescreve sempre o MESMO caminho
(`~/.config/browser-harness/tmp/shot.png`). Capturar vários pontos de scroll num
laço deixa todos apontando para um único ficheiro, e a análise de imagem que vier
depois descreve a última captura — ou uma captura de outra chamada inteira.
Copie para nome próprio no workspace logo após capturar
(`shutil.copy(p, os.path.join(ws, 'apps_700.png'))`) e analise esse caminho.

O sintoma é traiçoeiro porque a análise é internamente coerente: ela descreve com
segurança uma tela que existiu, só que não a que você acabou de medir. Se a
descrição contradiz o que os números do DOM dizem, suspeite do ficheiro antes de
suspeitar do código.

**Confirme o alvo ANTES de concluir qualquer coisa de uma medição vazia.** Antes
de aceitar um resultado — e obrigatoriamente quando ele vier vazio (`layout: []`,
`0 tiles`) — leia `location.href` e uma contagemâncora do DOM na MESMA avaliação:

```js
JSON.stringify({href: location.href, tiles: document.querySelectorAll('.e360-apps .icon-btn').length})
```

`about:blank` ou `chrome-error://chromewebdata/` significam que a página não está
lá — medição vazia é ausnência de página, não ausência de efeito. Tratar zero como
veredito nesse estado produz "o efeito sumiu" sobre código intacto, e leva a
inflar valores para compensar um defeito que não existe. Duas causas comuns aqui,
ambas já vistas: a aba foi sequestrada para `about:blank`, ou o dev server caiu
durante a sessão (`curl -s -o /dev/null -w "%{http_code}"` responde `000`) —
relevante porque a home é pesada de WebGL e a sessão de medição é longa.

Quando a navegação não assenta de primeira, o padrão que funciona é **uma única
chamada que faz tudo** — navegar, esperar, confirmar o alvo, medir, capturar —
com um laço curto de tentativas guardado pela âncora do DOM:

```python
for tent in range(3):
    try:
        ensure_real_tab()
        new_tab("http://localhost:5173/"); wait_for_load(); time.sleep(5)
        if js("document.querySelectorAll('.e360-apps .icon-btn').length") == 11:
            break
    except Exception as e:
        print("tent", tent, e); time.sleep(6)
```

Espalhar navegação, medição e captura por várias chamadas dá janela para o estado
mudar entre elas, e você mede um alvo diferente do que navegou.

O banner de consentimento cobre a base do ecrã e entra em toda captura; dispense-o
antes de fotografar, senão ele aparece na análise como se fosse a UI da página:

```js
(()=>{const b=[...document.querySelectorAll('button')].find(x=>/Recusar/.test(x.textContent));if(b)b.click();})()
```

## Bloom: o threshold se calibra contra a cena, não por valor plausível

Um `luminanceThreshold` acima do pixel mais claro da cena faz o composer rodar
todo frame, custar GPU e não acender nada. A paleta desta marca é escura;
qualquer threshold acima de ~0.6 é inerte aqui.

Calcule antes de escolher — `ACESFilmicToneMapping` com `toneMappingExposure`
comprime tudo para baixo:

```python
def srgb_lin(c):
    c = c / 255.0
    return c/12.92 if c <= 0.04045 else ((c+0.055)/1.055)**2.4
def aces(x):
    a,b,c,d,e = 2.51,0.03,2.43,0.59,0.14
    return max(0.0, min(1.0, (x*(a*x+b))/(x*(c*x+d)+e)))

for nome, hexv in {"struts": 0x167d5b, "nos": 0x125f47, "claro": 0x41d37a}.items():
    r,g,b = (hexv>>16)&255, (hexv>>8)&255, hexv&255
    lum = 0.2126*srgb_lin(r) + 0.7152*srgb_lin(g) + 0.0722*srgb_lin(b)
    print(nome, round(aces(lum * 0.88), 3))   # 0.88 = exposure do projeto
```

Referência medida nesta base: struts `#167d5b` ≈ 0.19, nós `#125f47` ≈ 0.09,
mais claro da paleta `#41d37a` ≈ 0.57.

Escolha o threshold **entre** o que deve acender e o que deve ficar fora: 0.42
deixa passar nós e facetas claras e mantém os struts escuros apagados,
preservando a leitura da malha. `luminanceSmoothing` alto (~0.35) dá joelho
largo; smoothing baixo produz o recorte duro de liga/desliga que denuncia bloom
mal ajustado. Com o threshold correto, `intensity` precisa **baixar** — o valor
que parecia seguro quando nada acendia estoura quando tudo passa a acender.

Critério de aceite: o wireframe ganha halo **e continua legível como malha**.
Borrão uniforme é threshold baixo demais.

## Vazamentos que nenhum portão acusa

- **`gsap.ticker.remove` compara por identidade de função.** Passar um arrow novo
  no cleanup não remove nada: o callback antigo continua no ticker chamando
  `lenis.raf` sobre instância já destruída, a cada troca de rota. Guarde a
  referência numa `const` e remova essa.
- **`renderer.dispose()` não alcança os render targets do composer.** O buffer de
  bloom é textura própria do `EffectComposer`; sem `composer.dispose()` no
  cleanup, cada remontagem da cena deixa framebuffers na GPU.
- **`prefers-reduced-motion` desliga o efeito inteiro.** Antes de investigar
  ausência de efeito, confirme `window.matchMedia('(prefers-reduced-motion:
  reduce)').matches` no navegador que você está medindo — falso alarme comum.

## Efeitos de Micro-interação Premium (Anti-Slop UI)

Para elevar o design além do comum sem hallucinar bibliotecas de UI (como Aceternity ou ReactBits aleatórios), use os padrões que já operamos na plataforma de forma nativa e otimizada (GSAP + CSS moderno):

- **Botões Magnéticos (`Magnetic.tsx`):** Não amarre `mousemove` bruto com CSS transitions. Animação amarrada ao ponteiro precisa rodar fora do Main Thread ou ser otimizada. Use `gsap.quickTo(el, 'x', { duration: 0.4, ease: 'power3.out' })` para acompanhar a inércia do cursor a 60fps sem lag.
- **Modais / Dialogs (`spring` vs `fade`):** O padrão "Premium" rejeita fade-ints básicos (`ease-out opacity`). A entrada do card (como o `e360-appcard`) deve projetar a camada: `transform: translate(-50%, -40%) scale(0.95); filter: blur(10px);` abrindo para `scale(1)` e sem blur, atrelado a uma curva de mola `cubic-bezier(0.16, 1, 0.3, 1)`. Use `backdrop-filter: blur(8px)` no scrim em vez de apenas opacidade para reforçar a separação da tela sem precisar de "cartões de vidro" literais.
- **Foco em Grade (Spotlight e Dimming):** Em listas (como `EcomAppIcons`), destacar o item sob *hover* exige diminuir fisicamente os pares não fofocados por percepção periférica. Faça pelo CSS com o seletor relacional `:has` ou combinadores simples: `.container:hover .item:not(:hover) { opacity: 0.4; filter: saturate(0.5); transform: scale(0.96); }`. Acompanhar com um *spotlight* de leitura (um gradiente radial `transparent` movido via variáveis CSS `--mouse-x`) amarra a iteração com a sensação tátil sem quebrar a leveza do DOM.

## Revelação de texto linha a linha (SplitType)

- **Nunca use `gsap.from` com `scrollTrigger` em texto.** O `from` aplica o
  estado inicial na **criação**, não no disparo: as palavras descem 100% e ficam
  atrás da máscara à espera do gatilho. Se o gatilho falhar por qualquer razão
  (medição feita antes das fontes, scroll suavizado que não notifica, elemento já
  dentro do ecrã ao carregar), o título fica **invisível para sempre**. Crie um
  `ScrollTrigger` com `onEnter` e chame o `from` lá dentro: o pior caso passa a
  ser texto sem animação, nunca texto ausente. Sintoma no medidor: estado final
  com `translateY` ≠ 0 em todos os títulos.
- **Partir o texto muda alturas — remeça os gatilhos.** As linhas novas deslocam
  tudo o que vem abaixo, e o `ScrollTrigger` continua a vigiar as coordenadas do
  layout anterior; o elemento entra no ecrã e nada dispara. Chame
  `ScrollTrigger.refresh()` depois de `document.fonts.ready` **e** depois de cada
  re-split.
- **Re-split no resize só quando a LARGURA mudar.** Em telemóvel, rolar mostra e
  esconde a barra do browser e dispara `resize` por mudança de altura a toda
  hora; re-partir aí refaz o layout do texto durante o scroll. Guarde a largura
  do último split e compare.
- **`types: 'lines,words'`, nunca só `'lines'`.** Com apenas linhas, animar o nó
  move a própria máscara junto com o conteúdo e não há recorte. As palavras
  precisam ser nós próprios: a linha fica parada com `overflow: hidden` e as
  palavras sobem por trás.
- **Só parta o texto depois de `document.fonts.ready`.** Medir com a fonte de
  sistema calcula quebras para métricas que mudam quando a fonte real chega, e o
  texto se reparte em outros pontos, com palavras cortadas ao meio da máscara.
  Pesa mais aqui do que num site monolíngue: são 4 idiomas, e uma frase não
  quebra no mesmo ponto em todos.
- **`yPercent: 100`, não pixels.** Valor absoluto falha nos títulos grandes e nos
  pequenos ao mesmo tempo.
- **Cascata por linha (`each` ~0.08), não por palavra.** Palavra a palavra vira
  máquina de escrever, que é outro efeito e cansa em duas telas.
- **`overflow: hidden` em texto corta descendentes** — o "g" e o "p" perdem a
  perna. Compense na máscara: `padding-bottom: .12em` com
  `margin-bottom: -.12em` devolve o espaço sem alterar o entrelinha.
- **Ordem do cleanup: `ctx.revert()` e só então `split.revert()`.** Ao contrário,
  o GSAP tenta animar nós que já não existem. Sem o `split.revert()`, cada
  navegação deixa o título partido em dezenas de divs, e um segundo split por
  cima gera lixo aninhado.
- **Estado inicial escondido mora no CSS, com escape sem JS.** `opacity: 0` no
  atributo e `opacity: 1` sob `html:not(.e360-motion-ready)`, senão o título
  some de vez quando o hook não roda.
- **Um nó, um dono.** Ao migrar um título de `data-reveal` para
  `data-line-reveal`, **troque o atributo, não some** — os dois disputam o
  `opacity` do mesmo elemento.

## Onde ligar, e onde não ligar

A home tem coreografia própria em `Ecom360Experience` (GSAP + WebGL + palco
grudado à tela). Sistemas genéricos de reveal entram apenas nas páginas internas:
`useLineReveal(location.pathname !== '/')`, mesmo critério do `useScrollReveal`.
Dois sistemas escrevendo nas mesmas propriedades do mesmo nó é conflito silencioso.

Os títulos dos capítulos da home, por isso, partem-se **dentro** do
`gsap.context()` de `Ecom360Experience`, não pelo hook genérico. Ao fazê-lo,
retire o título do conjunto que o array `entrances[]` anima (`copy.children`) e
deixe-o com movimento próprio — senão dois donos escrevem no mesmo nó. O resto do
bloco (kicker, corpo, botões) mantém a coreografia original.

A régua tipográfica por capítulo vive no CSS (`[data-chapter='N'] .e360-heading`)
e o split herda-a, porque as linhas nascem dentro do próprio `.e360-heading`:
não toque em tamanho, peso ou tracking para «ajustar» a animação. O que varia por
capítulo é a **cascata**, e ela escala com o peso tipográfico — título pesado
entra mais devagar e com mais intervalo entre linhas, porque massa visual grande
a mover-se depressa lê-se como salto. A prova de que os capítulos se movem
diferente é o contraste de quadros em movimento entre o mais leve e o mais
pesado; um par com 45 contra 100 quadros é diferença que o olho lê.
