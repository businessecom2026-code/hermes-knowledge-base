# Suíte que dá resultados diferentes na mesma árvore

Quando a mesma árvore produz 182/182 numa corrida e 143/182 na seguinte, sem
ninguém tocar em nada, o defeito é de **isolamento entre ficheiros de teste**, e
não do código sob teste. Este ficheiro trata desse diagnóstico.

O erro de enquadramento mais caro é tratar flake como um defeito único. Uma
suíte instável costuma ter vários vazamentos somados, e corrigir um faz o
sintoma mudar de sítio em vez de desaparecer — dando a impressão de que a
correção falhou.

## 0. Reproduza a instabilidade antes de corrigir

Uma corrida verde não refuta flake; uma vermelha não localiza a causa. Corra a
suíte inteira **3 a 5 vezes seguidas, sem alterar nada**, e guarde a saída:

```bash
for i in 1 2 3 4 5; do npx vitest run >> /tmp/runs.log 2>&1; done
grep -E 'Tests +[0-9]' /tmp/runs.log
```

Contagens diferentes entre corridas **provam** o flake e dão a lista de
candidatos. Contagens iguais mandam procurar noutro sítio: o problema pode ser
ordem de shard, paralelismo, ou ambiente — não vazamento entre ficheiros.

Esta mesma corrida repetida é a prova de aceite no fim. Sem ela, «corrigi o
flake» é autodeclaração.

## 1. Os quatro vazamentos que produzem flake em suíte de componente

Procure os quatro; encontrar um não dispensa os outros.

### Estado global declarado por ficheiro em vez de no setup

`globalThis.IS_REACT_ACT_ENVIRONMENT = true` escrito dentro de cada ficheiro de
teste cria dependência de ordem: o ficheiro que **não** o declara passa a verde
enquanto algum vizinho o tiver ligado antes, e arde quando corre primeiro ou
sozinho. O sintoma é dezenas de falhas concentradas num ficheiro que ninguém
mexeu.

A correção é um `setupFiles` único, carregado antes de qualquer ficheiro:

```ts
// vitest.setup.ts
globalThis.IS_REACT_ACT_ENVIRONMENT = true;
```

```ts
// vitest.config.ts
test: { setupFiles: ['./vitest.setup.ts'] }
```

Para achar os candidatos: `grep -L IS_REACT_ACT_ENVIRONMENT` nos ficheiros que
chamam `act(`.

### Relógio falso ligado no corpo do módulo

`vi.useFakeTimers()` fora de um `beforeEach` corre uma vez, no carregamento. Um
`vi.useRealTimers()` no `afterEach` de **outro** ficheiro desliga o relógio
global, e os testes seguintes medem a hora real. Em teste que depende de data
(«vence hoje», «expira amanhã») isto falha só depois da meia-noite ou conforme a
ordem — o pior tipo de vermelho.

Ligue o relógio e fixe a hora no `beforeEach` de cada ficheiro, sempre juntos:

```ts
beforeEach(() => { vi.useFakeTimers(); vi.setSystemTime(DATA_FIXA); });
afterEach(() => { vi.useRealTimers(); });
```

`setSystemTime` no `beforeEach` com `useFakeTimers` no corpo do módulo é a
variante mais traiçoeira: funciona no primeiro teste e perde o relógio do
segundo em diante.

### Teto de tempo dimensionado para o ficheiro isolado

`testTimeout` de 5s passa quando se corre um ficheiro e estoura na suíte cheia,
onde há contenção de CPU. As vítimas são sempre os testes que montam ecrã
inteiro — e o erro parece defeito do componente, não do teto.

Dimensione pelo caso pior sob carga, não pelo caso isolado. Um teto folgado não
esconde regressão: teste que regride falha por asserção, não por tempo.

### Contenção externa à suíte

Outro processo pesado na mesma máquina (outra suíte, um build, um worker do
board) triplica o tempo de corrida e faz estourar tetos que estavam bem
dimensionados. Antes de mexer na configuração, confirme que a máquina estava
livre durante a medição — corrigir teto por causa de contenção transitória
esconde o número real.

## 2. Separe o vazamento de quem sofre o vazamento

O ficheiro que **arde** raramente é o que tem o defeito. Antes de o editar, corra
os dois isoladamente:

```bash
npx vitest run <ficheiro-que-arde>        # verde sozinho => vazamento alheio
npx vitest run <ficheiro-suspeito> <ficheiro-que-arde>   # reproduz o par
```

Verde sozinho e vermelho na suíte é assinatura de dependência de ordem. Editar
asserção do ficheiro que arde, nesse estado, mascara o defeito e deixa a suíte
tão instável quanto estava.

## 3. Prove a hipótese por mutação da própria correção

A armadilha específica desta classe: concluir que um ficheiro depende do setup
novo e ir commitar sem verificar. Desligue o setup e corra **só** aquele
ficheiro. Se ele passar 41/41 sem o setup, a sua hipótese está errada — o
vazamento importa na suíte cheia, não isolado, e a causa real ainda está lá.

Vale a regra geral: correção de flake que não foi testada contra a ausência dela
é palpite com aparência de diagnóstico.

## 4. Aceite com corridas repetidas, não com uma verde

O critério de fecho é o mesmo procedimento da secção 0, depois da correção: N
corridas consecutivas, todas com a contagem cheia, número colado no card. Junte
`tsc --noEmit` e `eslint` limpos — correção de flake mexe em configuração e em
ficheiros de teste, e é fácil deixar diretiva órfã (`eslint-disable` de uma regra
que deixou de disparar) ou tipo global a faltar.

No fechamento, diga **quantas causas** foram encontradas e qual o sintoma de
cada uma. «Corrigi o flake» não permite à próxima sessão reconhecer o mesmo
padrão; «quatro vazamentos: flag global por ficheiro, relógio no corpo do módulo,
teto de 5s, contenção externa» permite.
