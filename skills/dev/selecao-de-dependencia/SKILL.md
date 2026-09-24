---
name: selecao-de-dependencia
description: Use ao escolher biblioteca ou pacote npm de terceiros.
metadata:
  hermes:
    tags: [dependencia, npm, licenca, bundle, frontend, avaliacao]
    category: dev
---

# Escolher biblioteca de terceiros

Vale para gráfico, tabela, UI, utilitário — qualquer pacote que se cogita
instalar. Duas perguntas, sempre nesta ordem: **esta biblioteca é adotável?**
(licença, peso, manutenção — fatos verificáveis) e **onde ela entra no NOSSO
código?** (qual arquivo encolhe, qual defeito de UX ela mata). Responder só à
primeira produz uma lista de pacotes que o usuário já podia ter achado no Google.

O script `scripts/verificar-pacotes.mjs` responde à primeira em um comando.

## 1. Nunca cite licença, peso ou popularidade a partir de blog ou memória

Post de "as 10 melhores libs do ano" repete licença de três anos atrás. Toda
afirmação numérica sai de API primária:

| Fato | Fonte |
|---|---|
| versão, licença declarada, data do último publish | `registry.npmjs.org/<pkg>` |
| downloads/semana | `api.npmjs.org/downloads/point/last-week/<pkg>` |
| tamanho min e gzip, tree-shaking | `bundlephobia.com/api/size?package=<pkg>` |
| licença SPDX real, estrelas, último push | `api.github.com/repos/<owner>/<repo>` |

Rode o script do skill (copie-o para `$LOCALAPPDATA/Temp` e chame `node`; não use
`/tmp`, que ferramenta nativa do Windows não resolve):

```bash
node "$LOCALAPPDATA/Temp/verificar-pacotes.mjs"
```

Encadear dezenas de `curl | node -e` num comando só é frágil e ilegível — um
arquivo `.mjs` com `await fetch` num laço custa o mesmo e dá para reler.

## 2. Três sinais que reprovam um pacote antes de qualquer análise técnica

- **Campo `license` que não é SPDX.** `"SEE LICENSE IN LICENSE"` no registry, ou
  `"NOASSERTION"` no `spdx_id` do GitHub, significa licença própria — quase
  sempre com teto de faturamento, proibição de uso em produto concorrente, ou
  cláusula de sublicenciamento. Abra o LICENSE antes de recomendar. Pacote que já
  foi MIT e deixou de ser continua listado como MIT em todo lugar menos no
  arquivo que vale.
- **Último publish parado há mais de ~12 meses** num pacote de UI ativa. Combine
  com o `pushed_at` do GitHub: repo quieto **e** registry quieto é projeto que
  migrou para modelo pago ou morreu. Não adote como dependência nova por melhor
  que a API pareça.
- **Peso que não se paga.** Compare o gzip com o que a tela precisa. Canhão de
  300+ KB para desenhar duas barras e uma linha reprova, mesmo sendo Apache-2.0.

Diga esses "não recomendo" no relatório, com o motivo em uma linha cada. A lista
do que foi descartado e por quê vale tanto quanto a recomendação — é o que impede
a próxima pessoa de reabrir a mesma opção.

## 3. Ancorar no código que está em obra

Recomendação sem endereço não é acionável. Descubra o que o projeto mexe de
verdade e o que ele faz à mão:

```bash
# arquivos mais tocados no período, no diretório que interessa
git log --since='60 days ago' --name-only --pretty=format: -- <dir> \
  | grep -v '^$' | sort | uniq -c | sort -rn | head -30

git log --oneline -15          # o tema dos commits recentes nomeia a dor atual
wc -l <candidatos>             # arquivo grande = implementação à mão acumulada
```

Depois procure a **reimplementação manual** que a biblioteca substituiria:

| Biblioteca | Sintoma de que já se faz à mão |
|---|---|
| gráfico | `viewBox=`, `<polyline`, `<path d=`, função que calcula `y` a partir do domínio, eixo desenhado com `<text>` ou `<span>` posicionado |
| tabela | `<thead>` repetido em telas irmãs, `Math.ceil(total/pageSize)`, `hidden lg:table-cell` fixo no JSX, ausência de `sortBy`/`orderBy` |
| layout | ordem dos blocos decidida no código, igual para todo usuário |

Cite **arquivo:linha** do que sai e do que fica. Sobretudo do que fica: a
aritmética de dinheiro, a função exportada que a suíte do backend importa, a
guarda com comentário explicando o incidente — nomeie essas como intocáveis, ou o
produtor as leva junto na refatoração.

## 4. O critério de desempate é o usuário leigo, não a API

Este usuário mede interface pelo teste de 5 segundos: bater o olho e entender
significado, urgência e próxima ação, sem jargão e sem depender de tooltip.
Traduza isso em critério técnico:

- Coerência com o sistema visual já instalado (Tailwind, tokens do próprio
  módulo) pesa mais que riqueza de features. Lib que traz o próprio tema entra
  brigando com o que já existe.
- Interação que funciona no toque ganha de interação que só funciona no hover.
  `<title>` dentro de SVG é o caso clássico: demora 1-2 s no desktop e não existe
  no celular.
- Ordenar clicando no cabeçalho da coluna é o gesto que todo leigo tenta numa
  lista. Se não existe hoje, é o ganho de maior retorno por linha escrita.
- Layout arrastável e personalizável é o item de **maior risco** contra o teste
  dos 5 segundos: só proponha com ordem inicial curada e botão de voltar ao
  padrão, e deixe por último.

## 5. Formato da entrega

Tabela com os números verificados (versão, licença, gzip, downloads), depois uma
seção por biblioteca dizendo **onde ela entra e o que ela apaga**, com
arquivo:linha. Depois a lista do que foi descartado. Depois a ordem de execução
proposta, do maior ganho isolado para o mais arriscado.

Feche nomeando os pontos que travam a execução e que você não decide sozinho
(testes que vão quebrar, gate de infraestrutura parado, custo de cota) e **uma**
pergunta de decisão. Não abra a resposta por commit nem por hash: o usuário cobra
resultado pelo nome do módulo de produto ("o financeiro", "os contatos").

## Pitfalls

- **Instalar antes de medir o custo dos testes.** Num repo que testa asserindo
  sobre o texto do fonte, trocar markup à mão por componente de biblioteca quebra
  todo teste que aponta para aquele arquivo. Conte-os antes de prometer prazo, e
  diga que a reescrita deles faz parte do escopo.
- **Somar o gzip da lib ao orçamento como se fosse custo fixo.** Com bundler
  moderno e tree-shaking só entra o que for importado; o número do bundlephobia é
  o pacote inteiro. Diga os dois: o teto e o que a tela realmente carrega.
- **Tratar wrapper React como dependência separada no peso.** O wrapper pesa 1-2
  KB; o custo está no núcleo que ele embrulha. Some o par antes de comparar.
- **Recomendar a lib do ecossistema que o projeto não usa.** Pacote de gráficos
  que só se justifica dentro de um design system ausente arrasta o design system
  inteiro junto. Reprove por isso, explicitamente.
- **Confundir template com dependência.** Código que se copia para dentro do repo
  (blocos de UI, admin templates MIT) não cria dependência nem peso de runtime —
  avalie pela licença e pela data do último push, e diga no relatório que é cópia,
  não `npm install`.
