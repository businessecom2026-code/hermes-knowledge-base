# Medição em navegador real

Receita para produzir a base factual de uma auditoria de front-end: números medidos, não estimados.

## Por que dirigir o navegador por protocolo

Dirigir o navegador por CDP (Chrome DevTools Protocol) devolve **número e texto** — FPS, heap,
resultado de clique, `elementFromPoint`, ordem de tabulação — que entram direto no relatório e o
usuário pode reproduzir. É a base factual, e nenhuma captura de tela substitui.

Não confunda isso com "screenshot não vale de evidência": vale, e às vezes é a única evidência
aceita — ver a seção de captura mais abaixo.

Subir o Chrome com `--remote-debugging-port=<porta>` e a janela **visível** deixa o usuário
acompanhar; `--auto-open-devtools-for-tabs` abre o DevTools junto.

## Você está medindo o app certo?

Antes de qualquer leitura que vá virar achado, prove **em qual origem** o navegador está. Máquina
de desenvolvimento acumula servidor na mesma faixa de portas: dev server deste projeto, preview de
build antigo, dev server de outro projeto do mesmo dono, e andaime de teste que um agente subiu
para medir componente isolado. Todos respondem 200 e todos parecem "o app".

```python
js("location.href"); js("document.title")
```

O título é a prova mais barata: andaime de medição e app real quase nunca compartilham `<title>`.
Para varrer as portas suspeitas sem abrir aba:

```bash
for p in 5173 4173 5199 5241 5300; do
  printf '%s ' "$p"; curl -s "http://localhost:$p/" | grep -o '<title>[^<]*</title>' || echo '(nada)'
done
```

Duas consequências que mudam veredito: medir no andaime devolve "a interface está idêntica" sobre
código que mudou centenas de linhas; e medir no preview de um build antigo devolve achado sobre
um app que não existe mais. Quando o usuário for julgar aparência, **suba você a origem certa e
entregue a URL exata** — não o deixe escolher entre as abas que estiverem abertas.

## Headless x janela visível — cheque antes de envolver o usuário

Um navegador headless responde a tudo por protocolo (URL, título, texto, clique) sem existir na
tela. Para medir, tanto faz; **para qualquer passo que o humano tem de executar — login, 2FA,
captcha, aprovação em dispositivo — headless é inútil e o pedido vira busca por uma janela que
não existe.** Confirme antes de pedir, não depois de ele reclamar:

```python
"Headless" in (js("navigator.userAgent") or "")   # True => nada na tela do usuário
```

```bash
# a janela existe mesmo? (Windows; o título é a prova)
powershell -NoProfile -Command "Get-Process chrome -EA SilentlyContinue | \
  Where-Object {\$_.MainWindowTitle -ne ''} | Select-Object Id,MainWindowTitle"
```

Sem janela, suba uma instância própria e visível, com perfil separado do Chrome pessoal do usuário:

```bash
chrome --remote-debugging-port=9222 --remote-allow-origins=* \
  --user-data-dir="<dir temporário novo>" \
  --no-first-run --no-default-browser-check --new-window "<url>"
```

Depois de abrir, **traga para a frente** (`Page.bringToFront`) e diga ao usuário o **título da
janela** que ele deve procurar na barra de tarefas — "abri a aba" não localiza nada quando há
dezenas de janelas abertas.

Perfil separado não é detalhe: usar o perfil pessoal mistura as abas e as sessões do usuário na
auditoria, e fechar a janela no fim destrói o que era dele.

### Perfil sujo sequestra a navegação

Estado de OAuth preso num `--user-data-dir` reaproveitado redireciona `/signup` e `/login` para o
provedor de identidade a cada tentativa, e a página que você pediu nunca aparece. Quando a mesma
URL cai repetidamente num destino que você não pediu, **descarte o perfil e crie um novo** em vez
de insistir na URL. Entrar pelo site público e navegar até o formulário dali também contorna o
deep-link sequestrado.

## Conteúdo em iframe: o `innerText` do topo mente

Aplicação servida dentro de um iframe — comum em ERP e em produto com shell separado do módulo —
deixa o `document.body.innerText` do documento de topo com **só o chrome**: menu, rodapé, banner
de plano. Medir ali devolve "tela vazia" e "não pintou" para navegação que funcionou
perfeitamente.

Detecte e desça para o documento interno antes de qualquer leitura:

```javascript
// same-origin: contentDocument acessível. cross-origin: null
const d = [...document.querySelectorAll('iframe')]
  .find(f => f.offsetWidth > 300)?.contentDocument;
```

Texto, botões, inputs, `styleSheets` e estado de modal passam a partir desse `d`, não de
`document`. Se `contentDocument` vier null (cross-origin), o iframe tem alvo CDP próprio: liste
`http://127.0.0.1:<porta>/json` e procure a entrada com `type: "iframe"`.

Consequência que muda conclusão: shell e conteúdo são **aplicações diferentes, com CSS próprio**.
Fonte, raio, duração e easing lidos no documento de topo não descrevem a tela onde a pessoa
trabalha — e uma comparação de design system feita nessa leitura sai invertida.

## Estrutura que funciona

Um script por etapa, numerado, num diretório de trabalho — não um script monolítico.
Cada etapa imprime seu resultado e o usuário vê a auditoria progredir. Quando uma etapa falha,
você reroda só ela.

Ordem sugerida: console → scroll/long tasks → FPS → emulação mobile com throttle de CPU →
acessibilidade → interatividade → contraste → rede/recursos → ciclos de memória.

## Armadilhas do CDP

- **Handshake do WebSocket recusado (403 `Rejected an incoming WebSocket connection`):** tem dois
  lados, e só resolver um mantém o erro. No cliente, suprima o header `Origin`
  (`create_connection(url, suppress_origin=True)` no `websocket-client`); no navegador, suba com
  `--remote-allow-origins=*`. Aumente também o tamanho máximo de mensagem — árvores de
  acessibilidade e listas de recurso estouram o padrão.
- **Reconecte pelo `/json` a cada etapa, não guarde o alvo.** A URL do WebSocket morre quando a aba
  navega ou o usuário fecha a janela; leia `http://127.0.0.1:<porta>/json` de novo e escolha o
  alvo pelo domínio. Antes de recriar a janela, cheque se a porta ainda responde — porta muda de
  estado entre um turno e outro (usuário fecha, reboot, crash).
- **`Input.dispatchMouseEvent` com `MouseWheel` trava** com alguma frequência. Para rolar,
  `window.scrollBy()` via `Runtime.evaluate` é determinístico e não depende de compositor.
- **Clique de verdade exige a sequência completa:** `mouseMoved` → `mousePressed` → `mouseReleased`.
  Só `mousePressed` não dispara handler de `click`.
- **Cada avaliação de JS tem janela curta; espera longa dentro dela estoura.** `setTimeout` de
  vários segundos numa única chamada excede o tempo de resposta do daemon e derruba a sessão no
  meio da medição. Espere em pedaços de ~1s e leve **duas ou três posições de scroll por chamada**,
  não a varredura inteira — medição em lotes pequenos sobrevive à queda e você reroda só o lote.
- **Sessão derrubada se recupera reconectando, não reinstalando.** Depois de um estouro, uma
  chamada de reconexão à aba real devolve o contexto com a página no estado em que estava; a
  medição continua de onde parou.

## Servidor de preview: subir, alcançar e derrubar

Medição de gate, SEO e conteúdo servido vale contra o **bundle de produção**, não contra o dev
server com HMR. Suba o preview do build, meça, derrube — e conte com estas três pedras:

- **Health check em `127.0.0.1` pode falhar com o servidor no ar.** Vários dev servers escutam só
  em IPv6 (`[::1]`), e `curl` para o literal IPv4 devolve falha de conexão. Confirme a porta com
  `netstat -ano | grep ':<porta>'` e use `localhost`, que resolve para os dois.
- **O PID que você iniciou não é o PID que escuta.** O comando de preview roda atrás de wrapper;
  mate pela árvore, usando o PID que o `netstat` apontou.
- **No bash do MSYS, `taskkill //PID` é mangled e recusado.** Chame via `cmd.exe /c "taskkill /PID
  <pid> /T /F"`, que passa as flags intactas.

Derrube o servidor ao terminar e confirme a porta livre: preview esquecido bloqueia a porta do
próprio próximo turno.

## Provar trabalho visual: captura + leitura de imagem

Medição por protocolo prova **comportamento**; não prova aparência. Quando o pedido é "quero ver
como ficou", tabela de `typeof`, contagem de nós e cookie gravado não respondem — o usuário está
pedindo a tela. Capture e leia a imagem:

1. Suba o preview do build, navegue e **espere a cena assentar** antes de capturar (experiência com
   3D, animação de entrada ou fonte web pinta em etapas; captura cedo registra estado intermediário
   que não existe para o usuário).
2. Capture a tela e passe o arquivo para leitura de imagem, com **pergunta fechada** sobre o que
   precisa ser provado: "o banner aparece? onde? os dois botões têm o mesmo tamanho? algum texto
   cortado?". Pergunta aberta devolve descrição de catálogo; pergunta fechada devolve veredito.
3. Para detalhe pequeno — texto de um componente, peso de dois botões lado a lado — recapture com
   **recorte da região** em coordenadas da imagem original, obtendo o retângulo do elemento com
   `getBoundingClientRect()`. O recorte preserva resolução; a tela inteira reduzida torna ilegível
   exatamente o que se quer julgar.
4. Capture **um estado por imagem** e percorra os estados que importam (vazio, aberto, aceito,
   recusado, rodapé). Uma captura só prova um estado, e é sempre o estado que você escolheu.

**A leitura de imagem acha classe de defeito que o DOM aprova.** Tamanho igual em pixels passa a
verificação programática e ainda assim um botão preenchido ao lado de um contornado tem peso visual
desigual — hierarquia, contraste, texto rente à borda, elemento decorativo cruzando conteúdo só
aparecem a quem olha. Quando o julgamento é estético ou de paridade visual, capture; não conclua
de `getComputedStyle`.

Repasse a ressalva ao usuário **com a origem** ("visto na captura") e não a corrija por conta
aprópria quando ela muda aparência: mudança visual é decisão dele, e o valor da captura é justamente
ter trazido a decisão à tona.

## Medições que rendem achado

| o que | como | o que revela |
|---|---|---|
| Clique real | varrer posições de scroll, clicar no centro do alvo, checar se o estado mudou | elemento visível porém inerte |
| Ordem de foco | disparar `Tab` N vezes e coletar `activeElement` | o que teclado não alcança |
| Foco programático | `.focus()` em vários pontos e comparar `activeElement` | confirma barreira independente do `Tab` |
| Quem recebe o clique | `elementFromPoint` no centro do alvo | camada invisível interceptando |
| Geometria de gráfico SVG | ler `x`/`y`/`width`/`height` de cada `rect` e comparar com o `viewBox` | série desenhada fora da área visível |
| Texto de gráfico em px reais | `font-size` do atributo × (largura renderizada ÷ largura do `viewBox`) | rótulo ilegível quando o gráfico vive em coluna estreita |
| Vazamento | navegar A→B→A várias vezes, comparar heap e contagem de contextos | adjudica alegação de recurso não liberado |
| Degradação | emular viewport móvel + throttle de CPU progressivo | onde a experiência colapsa |
| Conteúdo para robô | ler o HTML servido, sem executar JS | o que buscador e LLM realmente veem |
| Contraste | compor o alfa sobre o fundo real pelo motor do próprio navegador | evita falso positivo de parse de cor |
| Perda de foco | ativar outra janela pelo SO, esperar, voltar e comparar estado do formulário | modal que desmonta e apaga o que foi digitado ao alternar de janela |

## Regras de leitura

- **Opacidade e máscara não removem do hit-test.** Só `pointer-events`, `visibility` ou `inert`
  fazem isso. Elemento com `opacity: 0` continua interceptando clique.
- **Teste em condição justa antes de declarar bug.** Rolagem gradual, rolagem abrupta e várias
  posições — um único teste que falha pode ser timing, não defeito.
- **Varra o intervalo inteiro.** "Não funciona" só se sustenta depois de varrer as posições onde
  deveria funcionar; se funcionar em alguma, o achado muda de "quebrado" para "janela estreita"
  e a correção é outra.
- **A constante de fase no código não é a janela observada.** Transforms, atrasos por item e
  fases que se compõem deslocam o limiar em relação ao número declarado — e o comentário ao lado
  da constante envelhece. Cite sempre o intervalo **medido**, e se ele divergir da constante, diga
  as duas coisas: a divergência costuma ser o achado mais útil da varredura.
- **Traduza a janela para unidade que o usuário sente.** Fração de jornada não significa nada;
  multiplique pela altura do documento e entregue em pixels de rolagem. "Clicável por ~480px num
  documento de 6000px" é o número que transforma "funciona" em decisão de design.
- **Meça o efeito, não o intermediário.** Clique que não muda a URL não é clique perdido: pode ter
  aberto overlay, card ou modal no lugar. E `elementFromPoint` **depois** do clique devolve a
  camada que acabou de abrir, o que se lê como "algo interceptou". Antes de declarar interação
  quebrada, procure a mudança de estado real — nó novo no DOM, texto esperado dentro dele — e só
  então conclua.
- **Pegue o seletor no fonte, não por adivinhação.** `grep` os `querySelectorAll` do componente
  para saber a classe que o código de fato usa; tentar nomes plausíveis gasta chamadas e devolve
  contagem zero, que se confunde com "o elemento não existe".

## Gráfico se audita por aritmética, não por olhada

SVG escrito à mão concentra duas classes de defeito que passam despercebidas a olho e aparecem
em uma linha de medição.

**Escala montada sobre valores diferentes dos plotados joga a série para fora do quadro.** Quando
o domínio é derivado do dado bruto (com sinal, por exemplo) mas a barra é desenhada de um valor
transformado (`Math.abs`, acumulado, convertido), o transformado cai fora do domínio e a
coordenada sai negativa ou maior que a altura. A invariante que fecha a questão, para qualquer
entrada:

```javascript
const vb = svg.viewBox.baseVal;
[...svg.querySelectorAll('rect')].filter(r =>
  +r.getAttribute('y') < 0 ||
  +r.getAttribute('y') + +r.getAttribute('height') > vb.height
)   // precisa ser vazio
```

A correção é derivar o domínio **dos valores que serão desenhados**, depois da transformação —
não remover a transformação, que costuma existir por decisão de produto documentada ao lado.

**`font-size` dentro de SVG é unidade de `viewBox` e encolhe com o container.** Um rótulo
declarado `font-size="11"` num `viewBox` de 480 renderizado a 318px sai a 7,3px reais. Meça em
pixels de tela, nunca no atributo:

```javascript
const esc = svg.getBoundingClientRect().width / svg.viewBox.baseVal.width;
[...svg.querySelectorAll('text')].map(t => +(t.getAttribute('font-size') * esc).toFixed(1));
```

Meça em pelo menos três larguras de janela: quem "corrige" aumentando o número do atributo deixa o
texto gigante no container largo. A solução que sobrevive mede a largura real em tempo de execução
ou desenha o rótulo em HTML sobreposto ao SVG.

Ao revisar a correção, verifique também que sobreviveram as guardas de divisão por zero (domínio
com extremos iguais quando toda a série vale zero) e a proteção contra `NaN` — coordenada `NaN`
pinta gráfico em branco sem erro no console. Teste também: tudo zero, tudo positivo, tudo negativo,
uma série mil vezes maior que a outra.

**Gráfico bonito com escala incoerente é pior que gráfico visivelmente quebrado:** a barra cortada
o usuário percebe; a barra bem desenhada sobre eixo errado ele acredita.
