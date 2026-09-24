---
name: ecom360-plataforma-workflow
description: Use ao editar Ecom360co-Plataforma ou celular 3D.
---

## Redesign da Home — decisões já travadas com o dono

Estas três foram perguntadas e respondidas; não reabra a negociação, execute.

1. **"nenhuma animação nem nada, tudo limitado" é CRÍTICA, não ordem.** Ele acha
   a página pobre e quer salto de qualidade visual — não quer menos movimento.
   Ler essa frase como pedido de sobriedade inverte o trabalho inteiro.
2. **Port componente a componente**, adaptando para React 18 + Tailwind v3, com
   build verde a cada passo. Não migrar o site para React 19 / Tailwind v4.
3. **A seção de apps é a frente de trabalho**, por ser a do print.

Há um `Ecom360co-Plataforma/PEDIDO-REDESIGN-HOME.md` com o pedido verbatim. Leia
o pedido, mas **trate o diagnóstico dele como sintoma, não como causa**: ele
atribuía a grade 4-3-3-1 e a falta de headline a decisões de design, quando o CSS
já implementava 4-4-3 e já tinha `.e360-apps__title`. A causa real era um
off-by-one de DOM (ver a armadilha do seletor posicional). Corrigido em
`nth-of-type`; a grade entrega 4-4-3 medido.

**As "diversas bibliotecas" que o usuário instalou NÃO estão neste projeto.**
Estão em `C:/Users/judon/Documents/IGOR/motion-ui-kit` — projeto separado, criado
em 23/09, com motion 13.4, animejs 4.5, @react-three/fiber, drei, Spline, radix,
@visx/*, e 18 registries shadcn configurados. Se procurar no `package.json` do
site não vai achar nada novo e vai concluir, errado, que o usuário se enganou.

O kit é **incompatível de fábrica** com o site:

| | motion-ui-kit | Ecom360co-Plataforma |
|---|---|---|
| React | 19 | 18 |
| Tailwind | v4 (plugin Vite) | v3 (postcss) |
| TypeScript | ~6.0 | 5.3 |
| Gestor | npm | pnpm |

Copiar componente direto quebra. Porte um de cada vez, adaptando para React 18 +
Tailwind v3, com build verde a cada passo.

**A tabela é sobre o KIT, não sobre cada dependência dele.** Antes de assumir que
uma lib do kit exige migração, leia o peer range dela — várias declaram
`react: ^18 || ^19` e assentam no React 18 sem tocar no resto (`motion` 13.4 é
uma):

```bash
node -e "const p=require('./node_modules/<lib>/package.json');console.log(p.version,JSON.stringify(p.peerDependencies))"
```

Concluir "precisa de React 19" pela versão do kit descarta a via barata e compra
uma migração que ninguém pediu.

# Ecom360co-Plataforma Workflow

Carrega este skill ao trabalhar no projeto principal **Ecom360** (site `ecom360.co`), para não confundir com o produto irmão Accontax360.

O repositório local principal desta plataforma fica restrito à sua própria pasta:
`C:/Users/judon/Documents/IGOR/ecom360co/Ecom360co-Plataforma`

Ao ouvir "Ecom360" ou "celular 3D", vá para esta pasta, não para a pasta do Accontax360.

## 1. Visualização e Servidor Local (Vite)

Diferente do Accontax, a plataforma usa Vite na raiz.

- Subir o servidor local: `npx vite --port 5173` na raiz de `Ecom360co-Plataforma`.
  Use `npx`, não `npm run dev`: o script resolve `vite` pelo PATH e falha com
  `'vite' não é reconhecido` quando o binário local não está exposto.
- Suba em **background**, nunca em primeiro plano — servidor de watch não retorna
  e estoura o teto da ferramenta. Confirme com `curl -s -o /dev/null -w "%{http_code}"`.
- URL local padrão: `http://localhost:5173`
- URL de Produção: `https://ecom360.co`
- **Roteamento é `HashRouter`.** As rotas reais são `#/planos`, `#/servicos`,
  `#/contato`. Abrir `/planos` direto renderiza a Home e produz falso alarme de
  "regressão de roteamento" — todas as rotas parecem idênticas porque são.
  A falha é **silenciosa**: HTTP 200, sem erro no console, `location.pathname`
  devolve `/contato` enquanto o DOM é o da Home. Ler só a URL confirma a
  navegação que não aconteceu. Navegue com `location.hash = '#/planos'` ou
  clicando no link real, e **confirme pelo conteúdo** (a Home tem
  `h1.e360-title`; as internas têm `h1.e360-page__title`). Teste que navega por
  path direto valida a Home achando que está na página interna, e passa verde
  por engano — escreva isso no card de qualquer verificação visual.

O dono não quer preview nem localhost aberto no meio do trabalho: só abra quando
estiver pronto e verificado — e **derrube o servidor ao terminar**, confirmando
pela porta, não pelo PID que você lançou.

## 1a. Publicar no ar

"Sobe na produção" neste projeto quase sempre significa o PREVIEW, não
`ecom360.co`. São dois projetos Railway sobre o mesmo repositório, separados pela
branch observada. Antes de publicar, leia `references/deploy-railway-preview.md`:
qual projeto é qual, por que `Online` + HTTP 200 não prova que o seu código subiu,
e a config de pnpm que o builder exige.

O PID que a ferramenta de background devolve é do **wrapper**; quem detém a
porta é um node filho com outro PID. Matar o pai deixa o servidor vivo e `curl`
continua a responder 200 — parece que o kill falhou por outra razão.

```bash
netstat -ano | grep -E ':(5173|5205)' | grep LISTENING     # PID real, ultima coluna
powershell -NoProfile -Command "Stop-Process -Id <pid> -Force"
netstat -ano | grep -E ':(5173|5205)' | grep LISTENING || echo LIVRE
```

`Stop-Process` com PID **literal** é o que mata de facto. As outras formas
falham em silêncio: `kill <pid>` do bash não alcança o filho, `taskkill //PID`
recebe a barra dupla sem conversão do MSYS e recusa («argumento inválido»), e
`cmd //c "taskkill /PID n /T /F"` executa sem derrubar a porta. Um laço
PowerShell sobre vários PIDs (`foreach ($p in 1,2,3)`) é bloqueado pelo `dcg`
por expansão em runtime — uma chamada por PID, sem variável.

No fim de qualquer sessão com medição em navegador, cace órfãos antes de
entregar: `netstat -ano | grep -E ':(51[7-9][0-9]).*LISTENING'`. Servidores de
sessões anteriores sobrevivem por esta mesma confusão de PID e ninguém nota.

## 1b. Copy e idiomas

São 4 dicionários em colunas estreitas sobre a cena 3D. Antes de declarar copy
pronta, veja `references/copy-multilingue-verificada.md`: a chave e os códigos
reais de idioma (errá-los produz teste verde que nunca trocou de página), a
medição de transbordo por capítulo em desktop e 390px, e o critério editorial
que o dono cobra.

## 1c. Doutrina visual: anti-slop é requisito, não gosto

O dono rejeita explicitamente a solução genérica de "deixar premium" envolvendo
texto em cartão de vidro (`backdrop-blur`, borda, fundo translúcido). Ele chamou
de "card feio" e recusou duas vezes. **Não proponha cartão, painel, moldura ou
fundo atrás do texto dos capítulos** — o texto assenta solto sobre a cena 3D.

O que distingue a página não é decoração adicionada, é **composição**: régua
tipográfica própria por capítulo, numeração editorial, revelação por linha. Ver
`references/arquitetura-visual-home.md` para a arquitetura de capítulos e cenas.

O dono também recusa **partícula que não representa nada** — "não formam nada,
não tem direção visual". A régua é: cada elemento na tela tem de ser nomeável
(um app, um dado, um passo), não textura. **Mas "nomeável" não dispensa
movimento**: partícula parada é "estática, feia". Quando existir partícula, ela
tem de se mover — nomeável E viva, não uma coisa ou outra.

## Mensagem de commit desta sessão não descreve o commit

Um checkpoint `wip(...)` escrito no fim de uma sessão longa lista o que você
*lembra* de ter deixado pendente, e isso divergiu do diff: a mensagem prometia
"texto ainda em cartão com selo tipo pill" quando o mesmo commit **já tinha
removido** `.e360-parada__selo` e substituído a marcação por `.e360-estacao__*`
sem fundo nem borda. Rotear um card a partir dessa mensagem mandou um worker
consertar o que já estava consertado — dois runs de 50 min, zero linhas.

Antes de escrever card de correção sobre trabalho seu, leia o **código**, não o
seu próprio relato: `grep -rn '<classe do defeito>' components/ pages/`. Classe
ausente = defeito já morto. O CSS deste projeto documenta as decisões em
comentário ("Sem fundo, sem borda. Peso e cor fazem o trabalho que a pill
fazia") — esse comentário é evidência mais recente que qualquer mensagem de
commit, porque foi escrito ao mudar o código.

**A recusa ao cartão vale também para conteúdo novo que você inventar.** É fácil
ler "não ponha cartão atrás do texto dos capítulos" como regra sobre os capítulos
antigos e construir cartões numa secção nova — foi o que aconteceu no interior do
aparelho (`.e360-parada`, com selo colorido em pill), e a resposta foi a mesma de
sempre: "tem uma pill nada a ver nos cards, os cards estão toscos, amador". A
regra é sobre a LINGUAGEM VISUAL da home inteira: texto assenta solto na cena,
sem moldura, sem fundo, sem selo tipo etiqueta. Para construir ambiente e profundidade
em cena escura sem cair nas armadilhas de física de luz, e para o diagnóstico que
precede qualquer protótipo novo, veja `references/profundidade-cena-escura.md`.

Efeito tem de vir de **biblioteca instalada e importada**, não de snippet colado.
O dono recusa "control C control V do que acha que é o correto". Antes de
prometer um efeito, confirme que a lib existe em disco:

```bash
node -e "const p=require('./package.json');const d={...p.dependencies,...p.devDependencies};['lenis','split-type','postprocessing','motion','three','gsap'].forEach(k=>console.log((d[k]?'SIM  ':'NAO  ')+k))"
```

E que está **de fato importada** — lib instalada sem uso é o mesmo teatro:

```bash
grep -rn "from 'lenis'\|from 'split-type'" --include=*.tsx --include=*.ts . | grep -v node_modules
```

Importada ainda não é **visível**: o modo de falha dominante aqui é efeito que
compila, roda todo frame e não produz pixel nenhum. Nenhum portão estático pega
isso — só medição no navegador. Antes de declarar qualquer efeito pronto, veja
`references/efeitos-motion-verificados.md`: como provar movimento amostrando
`transform` no tempo, como calibrar threshold de bloom contra a luminância real
da cena, e os vazamentos de cleanup (`gsap.ticker.remove` por identidade,
`composer.dispose`) que passam verdes em `tsc` e `build`.

## 1e. Peso de assets: GLB e fontes

Os dois GLB pesavam 4,1 MB dos ~5 MB da home e o LCP era 27,5 s. Antes de
mexer em qualquer asset 3D ou tipografia, veja `references/peso-3d-e-fontes.md`:
por que `--simplify-ratio` não faz nada numa malha não soldada, por que o
pacote `geist` devolve 404 em CSS que nunca existiu, como medir `size-adjust`
sem introduzir CLS, e como escolher o nível de compressão por diferença de
pixel em vez de impressão visual.

## 1d. Elementos que o dono nomeia como intocáveis

A esfera wireframe com o wordmark, o celular 3D e os ícones entrando nele são o
núcleo que ele gosta e cobra pelo nome. Qualquer trabalho de refino preserva os
três; card que possa afetá-los declara isso como critério de reprovação.

Por isso, ao escolher biblioteca de motion/3D, prefira a que **entra por cima**
da cena existente (pós-processamento, smooth scroll, split de texto) em vez da
que exige reescrever a arquitetura. Migrar para `@react-three/fiber` jogaria
fora a coreografia GSAP da esfera e do celular — é perda, não upgrade.

## 2. O "Celular 3D" (iphone-viewer.html)

Sempre que a instrução envolver "celular 3D" ou "iPhone 18 Pro Max", trata-se do arquivo:
`Ecom360co-Plataforma/iphone-viewer.html`

**Atenção ao testar:** Este arquivo de inspeção avulso não entra no `dist` do Vite durante o build (só o `index.html` entra). Para abri-lo localmente para o usuário testar, inicie a task dev no background e acesse via `http://localhost:5173/iphone-viewer.html`.

## 3. Interior Imersivo / Corredor 3D (pós-portal)

Quando a narrativa promete "você está dentro" do aparelho, o visual deve pagar a promessa.
O padrão antigo — quatro capítulos sobre o mesmo campo de partículas em quatro arranjos
(scatter → mesh → pulse → return) — quebra a confiança: o visitante entrou e viu poeira.

**Procedimento**
1. **Prototipe isolado primeiro** — crie `prova-*.html` em `C:/Users/judon/ecom360-checkpoints/provas`
   com o corredor completo (chão, paredes, teto, moldura, vinheta) e o dado viajando.
   Valide altura, glow, ausência de erros de console, partículas zero.
2. **Cenário em CSS, não WebGL** — gradientes radiais/lineares + `perspective` + `transform-style: preserve-3d`.
   Zero contexto three.js novo, chunk não cresce. O movimento é uma variável CSS (`--e360-corredor-y`)
   escrita uma vez por quadro via `requestAnimationFrame` amortecido (`suave += (alvo - suave) * 0.08`).
3. **Um só dado atravessa tudo** — o componente recebe `paradas[]` (app, cor, hora, título, corpo, nota)
   e `valor`/`origem`/`fecho`. `IntersectionObserver` nas estações (`threshold: 0.55`)
   revela o cartão (`is-on`) e atualiza `atual` → o pip muda de cor e legenda.
   Narrativa paga: a venda entra no Flow360, cai no Financeiro360, vira tarefa, sai NF no Accontax360.
4. **Acessibilidade** — cenário decorativo com `aria-hidden="true"`; texto vive nas estações,
   com `id`/`aria-labelledby` corretos. Leitor de tela não ouve o corredor.
5. **Substitua, não acumule** — remova `ChapterField` (WebGL + three.js) e suas âncoras `.e360-chapter__bg`.
   Se o componente órfão ficar, carrega three.js sem desenhar nada. Delete os arquivos.
6. **Copy nos 4 idiomas** — a viagem vive nos dicionários `pt/en/es/it` com chaves `jornadaValor`,
   `jornadaOrigem`, `jornada[]`, `jornadaFechoTitulo/Corpo`. Mesmo horário, mesma venda,
   cores dos apps respeitadas.
7. **Verificação ao vivo obrigatória** — Playwright: scroll em porcentagens fixas (50/62/72/82/92/100%),
   capture `corredorAceso`, `dentroAtivo`, `dadoVisivel`, `legenda`, `paradasReveladas`, `particulasRestantes`.
   Screenshot em cada parada. `npm run check:structure` para paridade i18n e grafo.

**Armadilhas específicas do corredor**
- **`filter: blur` em elemento rotacionado dissipa a luz** — mediu 28 → 14 em vez de crescer.
  Tire o blur; ponha a suavidade dentro do próprio `radial-gradient` (ex: `transparent 68%`).
- **Contexto de empilhamento do `transform` corta sombra de pseudo-elemento** — o cartão tinha
  `transform` e seu `::before` (sombra/brilho) sumia. Envolva em `.assento` sem transform;
  mova sombra/brilho para ` .assento::before / ::after `.
- **Variável CSS que muda não prova movimento percebido** — `--e360-corredor-y`
  ia de 0 a 990px com a cena parecendo imóvel. Duas causas somam, e as duas têm
  correção conhecida:
  1. **O laço amortecido só corre enquanto há scroll**, logo com o dedo parado a
     cena morre. Resolve-se com um pulso próprio de relógio (uma variável de
     respiração em ciclo **primo** com o do fundo, para não batir) que a moldura
     consome como zoom mínimo. É a exceção legítima à regra do `progresso + f(tempo)`:
     respiração ambiente não ilustra progresso e não precisa de ser reversível.
  2. **A projeção achata a amplitude.** Sob `rotateX(70deg)` o eixo Y vale ~34%
     do nominal: 4px de deriva do chão lêem-se como ~1,4px e o olho não vê.
     Calibre a amplitude **dividindo pelo cosseno da rotação** em vez de subir
     valores às cegas, e escreva a conta no comentário.

  Amostrar a variável prova que o código corre, não que o olho vê — a prova é
  amostrar o `transform` **computado do elemento que se move**, 8 leituras a
  400ms com o `scrollY` travado, e exigir valores distintos.
- **Confirme o seletor contra o TSX antes de concluir «não move».** Um medidor
  que procura `.e360-moldura` quando a classe real é `.e360-corredor__moldura`
  devolve `sem elemento` e produz veredito de cena morta sobre código que
  funciona — quase custou a reprovação de uma entrega correta. As classes deste
  corredor são todas `e360-corredor__*`; leia-as de
  `grep -n 'className=' PhoneInterior.tsx` em vez de as deduzir do nome do
  conceito. Medição que devolve elemento ausente é instrumento cego, nunca
  ausência de efeito.
- **Altura total pode não cair** — 5 telas de partícula viram 5 telas de corredor (neutro).
  O ganho é semântico (direção visual), não métrico. Não prometa página mais curta.
- **Cookies cobrem base de `100vh`** — reserve `var(--consent-h)` no `padding-bottom` da última
  estação e do fecho. O banner publica a variável; `Footer` não existe na home.
- **`nth-child` desvia se a grade tem filho decorativo primeiro** — `EcomAppIcons` injeta
  `.e360-app-icons__spotlight` antes dos 11 `<button>`. Use `nth-of-type(button)`
  ou `nth-of-type` genérico que conta só o tipo alvo.
- **`display !== 'none'` não pega `visibility: hidden` / media query** — ao somar `textContent`
  de irmãos mutuamente exclusivos, filtre também por `getComputedStyle(el).visibility !== 'hidden'`.
- **Coreografia = função do progresso, nunca `progresso + f(tempo)`** — `GIRO_LIVRE = 0` travado.
  Quem rola devagar não pode acumular voltas extras; o efeito deve ser reversível ao rolar para trás.

## Armadilhas (Pitfalls)

- **Assumir Accontax360 por padrão na raiz de ecom360co:** São projetos diferentes na mesma pasta mãe. Ecom360 = `Ecom360co-Plataforma`, Accontax = `accontax360`. Se o usuário falar de ecom360, certifique-se de estar na pasta plataforma.
- **Entregar com diretórios novos fora do controlo de versões:** `git status`
  marca pastas inteiras recém-criadas com um único `??`, e um `git add` ficheiro
  a ficheiro deixa-as de fora. Localmente compila, porque estão em disco; o
  clone remoto quebra com `TS2307 module not found`. Antes de publicar:
  `git status --porcelain | grep '^??'` e use `git add -A`. Ficheiros de rascunho
  de agentes na raiz (`patch*.py`, `diff.txt`, relatórios `.md` avulsos) não
  entram no commit — apague ou ignore.
- **Procurar o celular 3D no build final:** A página de inspeção 3D (`iphone-viewer.html`) é injetada estaticamente para teste e não faz parte da rota do SPA/landing principal; rode ele no ambiente local.
- **Importação com Capitalização Errada (Casing):** O sistema Windows de ficheiros é case-insensitive, mas o `tsc` ou `Vite build` reprovará arquivos no import se a capitalização não bater exata com o nome do arquivo (`ChapterBackgrounds.ts` vs `chapterBackgrounds.ts`), o que quebra a transpilação num deploy no Railway (Linux). Verifique duplamente o nome do arquivo VS do import path caso `npm run typecheck` acuse "differs only in casing".
- **`start_dev.sh` falhando no Windows:** Scripts de monitoramento que tentam pingar portas com `nc` (netcat) falham no git-bash/MSYS e matam o servidor Vite junto, mesmo que ele tenha subido com sucesso. Inicie o servidor ignorando o script: `npx vite --port <porta> &`.
- **`'vite' não é reconhecido` persistente:** Se o ambiente estiver corrompido pela mistura de `npm` e `pnpm` (onde `node_modules/.bin` perde links e `npx vite` baixa a versão 8 desconfigurada), a solução é apagar a `node_modules` e rodar `pnpm install --force`. O projeto foi migrado nativamente para resoluções pnpm.
- **Camadas globais silenciosas (Grainient/Noise):** Sobreposições com `z-index` muito alto (`z-index: 30`) cobrindo a tela toda mascaram eventos de clique no `HashRouter` se o `pointer-events: none` falhar ou for ignorado pelo mix-blend-mode em certos contextos. Resultado: clique no link muda a URL de `#/...` localmente, mas não dispara o evento real.
- **Transições de Canvas amarradas a hardcodes de cena:** Efeitos portados (como Web Threads e Silk) calculam intensidade via índice fixo: `weightAt(scene, 3)`. Ao adicionar/remover seções ou rolar livremente, o índice real desencontra e o `mix()` resolve para `0`, zerando os pixels e gerando falha silenciosa "a tela sumiu". Isole a renderização forçando o peso para `1` ao depurar o Canvas.
- **O array `visibility` apaga capítulos de propósito:** `ChapterBackgrounds.ts`
  tem uma tabela por capítulo (`visibility = [1, 1, .18, .85, .8]`) que multiplica
  o `strength` de TODAS as cenas. O índice com `.18` é deliberado, não bug. Medir na
  fronteira desse capítulo interpola tudo rumo a `.18` e faz qualquer efeito novo
  parecer inexistente — você fotografa o ponto mais escuro da página e conclui que
  o código não funciona. Antes de mexer em opacidade de cena, leia essa tabela e
  posicione a medição no CENTRO do capítulo alvo (`centro - innerHeight/2`), onde o
  peso é `1`; retorne `{from, to, prog, pesoDaCena, fatorVisibilidade}` junto com o
  screenshot e descarte a leitura se o peso não for ~1. Nunca inflar opacidade ou
  espessura em resposta a um único screenshot escuro: estoura o visual onde ele já
  estava certo e tem de ser revertido valor a valor quando a causa real aparece.
- **Seletor posicional em grade que tem filho decorativo:** `EcomAppIcons` injeta
  um `<div class="e360-app-icons__spotlight">` como PRIMEIRO filho de
  `.e360-apps__grid`, antes dos 11 `<button>`. Toda regra `nth-child(N)` na grade
  passa a cair no tile N−1: a centragem da última fileira quebrava a linha uma
  coluna cedo e a grade entregava 4-3-3-1, com um app sozinho e o buraco no canto
  inferior direito — defeito que se lê como erro de design e não é. Use
  `nth-of-type`, que conta só os `<button>`. O mesmo deslocamento atinge qualquer
  código que indexe por posição entre os filhos da grade: `Home.tsx` mapeia o tile
  clicado para `APPS[]` com `indexOf` em `tile.parentElement.children`. Confira
  esse alinhamento sempre que mexer nos filhos da grade — um off-by-one aí abre o
  card do app errado e nenhum portão estático acusa.
- **Componente importado não é componente renderizado:** `Navbar.tsx` está
  importado em `App.tsx` mas nunca aparece no JSX — a navegação viva é
  `DockNav`. Auditar o ficheiro errado produz um diagnóstico inteiro (regras
  `!important`, contraste, z-index) sobre código que não pinta um pixel, e a
  correção real fica por fazer. Antes de medir ou corrigir qualquer componente
  de UI, confirme que ele entra na árvore: `grep -n "<Navbar\|<DockNav" App.tsx`.
  A lista de imports mente; só o JSX conta.
- **Há DOIS sistemas 3D nesta home, e o eixo da correção é oposto em cada um.**
  O corredor é CSS 3D (`components/experience/PhoneInterior.tsx`: perspective,
  `preserve-3d`, variáveis CSS); a esfera, o celular e os **ícones** são WebGL
  (`components/experience/scenes/*.ts`: `renderOrder`, `depthWrite`,
  `depthTest`). Card que nomeia o ficheiro errado queima o run inteiro: o worker
  audita `z-index` de um elemento que não existe, enquanto o defeito real é
  ordenação de transparentes no three. Antes de escrever card sobre elemento
  visual, descubra quem o renderiza — `grep -rn '<nome do elemento>'
  components/` — e nomeie ficheiro **e** tecnologia no corpo. Ausência do termo
  no `.tsx` que você acabou de criar não é prova de que o elemento não existe;
  é prova de que vive noutro sistema.
- **Nav que troca de cor por rota tem um estado de contraste por fundo:** o
  `DockNav` alterna a classe `.is-over-scene` — claro sobre a cena escura da
  home, escuro sobre as páginas internas de fundo claro. Medir só a home aprova
  uma nav com 1.37:1 nas internas (AA exige 4.5:1), praticamente invisível.
  Meça os DOIS estados, e confirme que a troca aconteceu pelo CONTEÚDO da
  página, nunca pela URL — com `HashRouter` a URL muda sem que a rota mude.
- **Medir o wrapper e culpar o componente:** os CTAs desta Home são um `<Link>`
  (ou `<button>`) dentro de uma `div` de posicionamento que carrega o nome da
  classe semântica. `querySelector('.e360-apps__cta')` devolve a DIV: sem `href`,
  sem `onclick`, e você reporta "botão decorativo que não clica" sobre um botão
  que funciona. Ao medir interatividade, desça ao elemento que a carrega
  (`wrapper.querySelector('a,button')`) e confira `tagName` antes de concluir.
- **`display` não filtra o que `visibility`/media query esconde:** ao somar
  `textContent` de nós irmãos que se excluem por media query, filtrar só por
  `display !== 'none'` deixa passar o nó oculto por outro mecanismo, e a leitura
  volta as duas frases concatenadas ("Toque…Clique…") — um defeito que não existe
  na tela. Confirme no screenshot com `vision_analyze` antes de "corrigir"
  qualquer coisa que só apareceu na string da medição.
- **O banner de cookies ocupa a base da viewport:** qualquer elemento novo no fim
  de um palco `height: 100vh` (CTA, última fileira de ícones, rótulo) nasce atrás
  dele até o visitante aceitar ou recusar. Ao adicionar algo ao rodapé de uma
  seção, meça o topo do banner e compare com a base do elemento — medir só
  `bottom <= innerHeight` diz "cabe" para algo que está coberto.
  O mecanismo de reserva é a variável `--consent-h`, publicada pelo próprio
  banner. `Footer`, `InnerPages.css` e `WhatsAppButton` já a consomem — mas a
  home ficou de fora durante muito tempo, porque a reserva tinha sido pendurada
  no `Footer` e o `Footer` não é renderizado na home (`App.tsx:160`). Ou seja: a
  única página com pixel de marketing era a única sem reserva.
- **Com `align-items: flex-start`, nem `min-height` nem `padding-bottom` mexem
  o conteúdo.** Para subir um CTA que fica sob o banner, é o `padding-top` que
  o desloca — reduzi-lo por `var(--consent-h)`, com piso (`max(…, 3.5rem)`)
  para o hero não colar na navbar. Encolher a caixa ou almofadar a base só muda
  onde a caixa acaba: o conteúdo está ancorado ao topo e o botão fica onde
  estava (no caso do `padding-bottom`, a caixa até cresce). Duas tentativas
  foram gastas antes de medir o `getBoundingClientRect` do próprio CTA.
- **Verificar sobreposição por geometria, com dois filtros obrigatórios:**
  comparar rectângulos e usar `elementFromPoint` no centro do alvo. Filtrar (a)
  só elementos dentro da viewport e (b) opacidade ACUMULADA dos ancestrais > 0
  — esta home mantém no DOM blocos com `opacity: 0` (`.e360-phone-portal`)
  cujos CTAs não são clicáveis de propósito. Sem o filtro (b) o teste reporta
  defeito em elemento que ninguém vê.
- **Espaço morto duplicado no palco de `100vh`:** antes de reduzir tipografia ou
  gap para caber mais um elemento, procure `padding-bottom` E `margin-bottom` na
  mesma regra — aqui a grade acumulava 1.5rem de cada para um único efeito, 48px
  de folga grátis. Encolher o conteúdo antes de ler o box model troca legibilidade
  por espaço que já existia.
- **Contagem de pixels do canvas não prova geometria:** "2687 pixels acesos" não
  distingue reta de curva, fio de ponto, grade de onda. Toda afirmação sobre FORMA
  ("os vínculos viraram fios curvos") exige screenshot + `vision_analyze` perguntando
  a geometria de modo literal. Relatar forma com base em contagem de pixels é
  entregar como verificado algo que nunca foi olhado. O screenshot tem de ser o
  DESTA medição — ver a higiene de captura em `references/efeitos-motion-verificados.md`.
- **`time` do laço de render cresce sem limite:** funções de oscilação que recebem
  o `elapsed` acumulado (`Math.sin(time * .45 + i)`) viram ruído depois de alguns
  minutos de página aberta, porque o ângulo sai da faixa em que passos consecutivos
  são pequenos. Dobre o ângulo em `tau` antes do `sin`. O defeito não aparece em
  teste curto — só em aba deixada aberta.
- **Coreografia que soma tempo ao scroll dá voltas a mais para quem rola devagar:**
  `PhoneExperience.ts` tinha `GIRO_LIVRE` (rotação por relógio) somado ao ângulo
  derivado do progresso de scroll. O caminho projetado era de ~1 volta, mas quem
  rolava devagar acumulava até 2,4 — exatamente a queixa de "os ícones ficam
  circulando várias vezes antes de entrar". Já está zerado; mantenha em 0.
  Regra geral: movimento que ilustra progresso é **função do progresso**, nunca
  `progresso + f(tempo)` — senão a duração do gesto muda a coreografia e o efeito
  deixa de ser reversível ao rolar para trás.
