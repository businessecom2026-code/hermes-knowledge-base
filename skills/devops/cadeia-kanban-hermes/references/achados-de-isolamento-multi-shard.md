# Conferir achado de isolamento (tenant, país, shard)

Como verificar, em minutos, um achado de auditoria sobre dado que atravessa a
fronteira entre bancos/tenants — antes de escrever o card que manda corrigir.

## O que checar, na ordem

1. **A premissa**: o código faz mesmo o que o achado descreve? Rode, não releia.
2. **A gravidade**: o passo seguinte tem guarda própria? Ver «defesa em
   profundidade» abaixo.
3. **A classe**: quantos chamadores passam pelo mesmo ponto? `grep` do símbolo
   com parêntese.
4. **O precedente**: alguém no repo já resolveu isto? Comentários que citam outro
   arquivo («mesma forma de X», «mesmo padrão de Y») apontam a decisão já tomada
   — reaproveitar é mais barato e mantém a convenção única.

## O shard é escolha de quem invoca ou parte do dado?

Antes de exigir que **todo** script aceite `--country=`/`--tenant=`, separe as
duas naturezas — a regra errada aqui reabre o defeito pelo outro lado:

| Natureza | Forma correta | Sinal de leitura |
|---|---|---|
| Opera sobre o que **já existe**, em qualquer shard | argumento obrigatório, sem default | purga, convite, backfill, diagnóstico |
| **Escreve** um caso concreto de um shard | constante tipada pelo enum | documento, território, regime fiscal cravados no arquivo |

Seed com identificador fiscal, território e referências de órgão de um país tem o
país **no dado**. Aceitar argumento ali oferece um botão que só serve para errar:
planta o registro de um país no banco de outro — a versão cara do defeito que a
separação existe para impedir.

O que a guarda de contexto exige é que o país seja **declarado**, não que venha
de fora. Constante tipada pelo enum dentro de `runWithCountry` satisfaz a guarda.
Conte os marcadores do domínio no arquivo (`grep -c` de documento, território,
código de órgão) antes de julgar: é a evidência que decide, e vale comentá-la no
card para o confirmador não tratar a decisão como pendência.

## Unicidade de coluna vale DENTRO de um banco

`@unique` no schema é restrição do banco. Num sistema com um banco por país (ou
por tenant), a mesma chave pode existir em todos eles: cada shard responde
«livre» porque só enxerga a si próprio. Toda função que gera identificador
consultando `findUnique` num único cliente produz colisão entre shards por
construção.

Dois agravantes a procurar:

- **Gerador determinístico a partir de dado do cliente** (nome normalizado,
  slug, documento). Se a entrada repete entre países — e nomes comerciais
  repetem — a saída colide sem aleatoriedade nenhuma para salvar.
- **Consumidor que varre shards e faz `break` no primeiro que casa.** Com chave
  colidida, o recurso é entregue ao tenant errado, e a ordem de
  `configuredCountries()` decide qual. É vazamento de dado entre países mesmo
  com a guarda de contexto intacta: o país foi resolvido, só que errado.

Escreva no card que a correção alarga o alcance da consulta na **função
geradora**, e que os identificadores já colididos em produção precisam de
backfill à parte — a correção previne os novos, não limpa os antigos.

## Validar contra o enum não é validar contra o que existe

Entrada que escolhe shard (`--country=`, `--tenant=`) costuma ser validada
contra o enum do schema. O enum lista o que o domínio conhece; não lista o que
está configurado neste ambiente. Um valor legítimo do enum sem banco provisionado
passa na validação.

Sinal de leitura: a função **já importa** a lista real de recursos configurados
mas a usa só para compor a mensagem de erro. Confira se ela aparece na condição
do `if`, não apenas no texto.

Ao mandar corrigir, peça a justificativa do efeito colateral: validar contra o
que está configurado faz um ambiente parcialmente provisionado rejeitar valor
legítimo. Para comando destrutivo isso é desejável (falha cedo); para
diagnóstico pode não ser. A decisão é por script, e vai escrita no card.

## Defesa em profundidade muda a gravidade, não a existência

A segunda guarda (o cliente que se recusa a abrir conexão sem URL configurada, o
Proxy que lança fora de contexto) costuma transformar «apaga no banco errado» em
«falha de configuração tardia e confusa». O defeito continua real e a correção
continua devida — mas passa a ser **mover a rejeição para mais cedo, com
mensagem útil**, e não blindagem de emergência.

Prove rodando a chamada seguinte isoladamente e cole a mensagem no card. E
marque o arquivo da guarda como intocável, com critério explícito de reprovação:
`git diff HEAD -- <guarda>` tem de sair vazio. Foi a guarda que impediu o achado
de ser grave; um produtor apressado "resolve" o erro removendo-a.
