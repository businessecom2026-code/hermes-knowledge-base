---
name: auditoria-ui-de-modulo
description: Use ao auditar a UI de um módulo existente.
---

# Auditar a UI de um módulo já existente

Carrega isto em pedidos do tipo «analisa o que dá para melhorar na interface»,
«tem informação repetida», «coisas que talvez confundam um cliente», ou «o que
destas bibliotecas nos ajuda».

Auditoria é **leitura**: não aplicar mudança nenhuma até o utilizador escolher o
que quer.

## 1. Fixar o âmbito ANTES de abrir qualquer ficheiro

O utilizador nomeia módulos no vocabulário **dele**, que raramente é o do código
nem o do menu. Antes de inventariar seja o que for:

- **Mapear cada nome dito para ficheiros concretos** e confirmar numa linha. «O
  módulo de clientes» pode ser o cadastro de contactos, a carteira do escritório
  ou a ficha do cliente — três módulos distintos com nomes parecidos.
- **Não alargar para a plataforma inteira.** Inventariar todos os componentes e
  todo o menu quando foram pedidos dois módulos gasta a sessão a produzir
  contexto que ninguém pediu. Dois módulos são dois módulos.
- Se o nome for ambíguo, perguntar numa linha em vez de adivinhar. Auditar o
  módulo errado só se descobre no fim.

## 2. Ler a camada de COPY primeiro, nunca o JSX

A duplicação que o utilizador vê é duplicação de **texto**, e o texto vive nos
ficheiros de tradução/copy — que são ~10x mais pequenos que os componentes. Dois
módulos podem ser 7.000+ linhas de JSX e 1.500 de copy com os mesmos achados.

```bash
# onde vive o texto
ls src/lib/*copy*.ts src/locales/messages/ 2>/dev/null
# os rótulos de um conceito, lado a lado
grep -nE "'(Saldo|Total|Resultado|Movimento)[^']*'" src/lib/<modulo>-copy.ts
```

O que salta à vista aqui e não no JSX:

- **O mesmo conceito com N nomes.** Contar quantos rótulos diferentes descrevem
  a mesma grandeza. Seis nomes para variações de «quanto sobra» é um defeito de
  vocabulário, não de layout.
- **Singular/plural a significar coisas diferentes** («Cliente do escritório» = um
  vínculo; «Clientes do escritório» = a lista inteira). Colisão garantida.
- **Duas portas para o mesmo destino** — dois botões que abrem o mesmo cadastro
  com critérios de escolha invisíveis.
- **Duas entradas de menu com nome quase igual**, onde a diferença real é de
  disponibilidade (uma só aparece para um país/plano). Quem só vê uma delas lê o
  nome sem o contraste que o justificava.
- **Rótulo que promete leitura e entrega formulário** («Relatório» cuja aba
  inicial é de lançamento). Verificar sempre qual sub-aba abre por omissão.

### Nota de rodapé a explicar que os números não batem = defeito de nome

Quando o ecrã precisa de uma frase a avisar que dois totais **não** devem ser
somados, o problema está no nome dos totais, não no texto. Procurar essas notas é
a forma mais rápida de encontrar vocabulário partido:

```bash
grep -niE "não (têm de|tem por que) (bater|cuadrar)|no tienen por qué|not a bank balance" src/lib/*copy*.ts src/locales/messages/*.ts
```

Corrigir renomeando, não acrescentando mais uma nota.

## 3. Verificar a fractura de i18n

Um módulo com copy própria costuma cobrir menos idiomas que a app. O utilizador
vê a app na língua dele e **aquele módulo em inglês**.

```bash
grep -n "return locale" src/lib/*copy*.ts      # fallback real do módulo
ls src/locales/messages/ | wc -l               # idiomas da app
```

Um fallback `locale.startsWith('pt') ? pt : locale === 'es' ? es : en` num repo com
10 locales significa que todos os outros idiomas caem em inglês naquele módulo.

Copy indexada por posição (`chartCopy.pt[0]`, `[1]`, …) é pior ainda: um idioma a
menos numa das listas desalinha tudo em silêncio, sem erro de compilação.

Antes de propor unificação, contar o custo: um `t()` com interface de chaves
tipada obriga a editar **todos** os ficheiros de locale de uma vez, porque a chave
em falta é erro de compilação. É o item que deixa de ser «só copy».

## 4. Bibliotecas instaladas e paradas

O utilizador costuma perguntar isto por já ter instalado coisas. Datar a entrada
de cada dependência e contar os usos REAIS:

```bash
git log --oneline -S'"<lib>"' -- apps/web/package.json | tail -2   # quando entrou
grep -rl "from '<lib>'" --include=*.tsx src | wc -l                # quantos usam
```

Distinguir sempre **instalada** de **usada**: um plugin registado no
`tailwind.config` com dois usos em toda a app está parado, e as classes que o
Tailwind core já traz (`animate-spin`, `animate-pulse`) não contam como uso dele.

Um helper exportado com zero importadores (um `cn()` em `lib/utils.ts` que
ninguém chama) é o achado mais valioso: a lib já está paga e o código continua a
montar classe com template literal cru. Sem `twMerge`, classes em conflito ficam
**as duas** na string e quem vence é a ordem no CSS, não a intenção — procurar
literais que acrescentam `bg-`/`border-` por cima de uma constante que já os traz.

## 5. Duplicação estrutural: dois controlos, um estado

A repetição mais confusa não é visual, é de comportamento. Procurar a variável de
estado escrita em dois sítios da mesma tela:

```bash
grep -n "setStatus\|setFiltro\|aria-pressed" src/components/<Tela>.tsx
```

Dois controlos a escrever no mesmo estado com rótulos divergentes («Total» num,
«Todas» no outro, ambos o valor vazio) fazem o utilizador clicar num e ver o
outro mudar sozinho.

## 6. Formato do relatório

Preferências fixas deste utilizador:

- **Cada achado com `ficheiro:linha`.** Afirmação sem âncora não se verifica e
  não se corrige.
- **Tabela para inventário** (lib → situação real, padrão → idiomas → onde).
  Prosa curta com o mecanismo para o que precisa de ser explicado.
- **Ordenar por retorno**, não por gravidade teórica, e dizer quais itens são só
  copy/estrutura (verificáveis no ecrã) e quais mexem em muitos ficheiros.
- **Critério de leigo**: o teste é se alguém entende significado, urgência e
  próxima acção ao bater o olho, sem tooltip nem jargão.
- **Terminar com uma escolha concreta** — qual item aplicar primeiro — em vez de
  começar a aplicar.

Ver `references/leitura-eficiente-de-codebase.md` para os comandos de mapeamento e
os contornos que evitam gastar chamadas.

## Antipadrões

- Inventariar a plataforma toda quando foram pedidos dois módulos.
- Ler milhares de linhas de JSX antes de abrir os ficheiros de copy.
- Assumir que o nome dito pelo utilizador é o nome do módulo no código.
- Abrir dev server ou preview durante a auditoria: este utilizador quer o
  resultado fechado, não o processo.
- Aplicar correcções durante a auditoria sem ele escolher o que entra.
- Escrever recomendações ainda não aplicadas como se fossem factos do código.
