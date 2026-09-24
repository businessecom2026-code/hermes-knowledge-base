---
name: limpeza-de-dados-em-producao
description: Use ao apagar dados de teste numa base de produção.
---

# Apagar dados numa base de produção

Aplica-se a: limpar dados de teste ou de smoke-test, remover registos com nome do próprio dono, apagar duplicados ou contas antigas — sempre que o alvo vive numa base que serve clientes reais, e sempre que o pedido chega como "limpa o que for teste" sem lista fechada.

O risco desta classe não é escrever o `DELETE` errado. É **classificar mal um registo**: apagar um cliente verdadeiro por o nome parecer de teste, ou deixar sujeira ligada a um registo que saiu. As duas coisas só se evitam medindo antes.

## Regras sempre válidas

1. **Nunca apagues na primeira sessão em que o alvo aparece.** Inventário primeiro, num script sem um único `DELETE`. A lista que sai do inventário é a única coisa que o utilizador pode aprovar; uma lista de memória não é aprovável.
2. **Aprovação por ID, nunca por padrão.** O script final recebe IDs exactos numa constante. `WHERE name ILIKE '%teste%'` em produção apaga o que entrar na base entre a aprovação e a execução. O padrão serve para *descobrir* candidatos; o ID serve para *apagar*.
3. **Confirma a identidade de cada ID dentro do script, antes do `DELETE`.** Lê `name` de cada ID e compara com o nome que foi aprovado; aborta se divergir. Um ID copiado da linha errada do inventário apaga o vizinho em silêncio.
4. **Classifica teste-vs-real pelo que está amarrado, não pelo nome.** Conta as filhas de cada candidato. Registo de teste tem 0 ou 1 linha vazia; registo real tem conversas, tickets, lançamentos, histórico. Ninguém troca nove mensagens com um cadastro de teste — essa assimetria é o sinal mais fiável que existe, e passa à frente de qualquer semelhança de nome.
5. **Levanta a coorte inteira da tabela, não só os candidatos que o padrão apanhou.** Conta as filhas de *todas* as linhas e ordena por total: os grupos separam-se sozinhos e dão-te a linha de base que torna cada classificação defensável. Sem coorte não sabes se "1 filha" é pouco ou é o normal daquela tabela. Isto também é a única forma de apanhar registo de teste cujo nome não contém marca nenhuma de teste — o padrão por nome descobre candidatos, nunca prova que a lista está completa. Três discriminadores, além do total, em `references/postgres-dependencias-e-orfaos.md`.
6. **Lê a regra `delete_rule` de cada chave estrangeira antes de confiar no cascade.** `CASCADE` cai sozinho; `SET NULL` **não apaga a filha** — deixa-a órfã com o vínculo em branco, que é exactamente o lixo que o utilizador pediu para não existir. Apaga as `SET NULL` explicitamente, antes do pai. Consultas em `references/postgres-dependencias-e-orfaos.md`.
7. **Descobre as dependências pelo catálogo do Postgres, não por lista escrita à mão.** Uma lista de tabelas envelhece a cada migração e a que falta é a que fica órfã.
8. **Tudo dentro de uma transacção, com guarda do que NÃO pode ser tocado.** Ao fim da transacção, relê os registos protegidos e compara com a contagem inicial; se divergir, lança erro e a transacção desfaz-se. A guarda dentro da transacção é o que separa "acho que não toquei" de "está provado que não toquei".
9. **Ensaio antes de gravar.** O mesmo script corre sem `--executar` e lança um erro de aborto no fim da transacção, revertendo tudo. Os números do ensaio têm de bater exactamente com os da execução; se não baterem, algo mudou na base entre as duas e a aprovação já não vale. Esqueleto em `templates/limpeza-guardada.cjs`.
10. **Verifica com um script separado, escrito depois.** O script que apagou não é testemunha do que apagou — reporta as suas próprias intenções. Um segundo script confirma: nenhum alvo sobrou, os protegidos estão inteiros com as filhas todas, zero órfãos, contagens das tabelas que não deviam mexer inalteradas.
11. **Tira os scripts do repositório no fim.** Guarda-os em `$LOCALAPPDATA/Temp` e confirma com `git status --porcelain`. Script de apagar em produção versionado é uma arma carregada para a próxima pessoa que correr o ficheiro sem ler.
12. **Confirma o destino da base antes de acreditar no inventário.** Imprime host e nome da base (nunca a senha) de cada URL. O `.env` local costuma apontar para base local: o inventário sai vazio ou errado sem nenhum erro visível, e parece que os dados já não existem. Aplicação multi-região tem mais de uma base — percorre todas e reporta por base. Como ligar de facto (rede privada, execução dentro do container, invocação que não estoura o `dcg`) em `references/executar-script-contra-base-remota.md`.

## Quando o pedido se contradiz

Pedidos desta classe chegam quase sempre em duas metades que se batem: *"apaga tudo o que for teste ou tiver o meu nome"* mais *"não podes afectar nenhuma conta nem nenhum cliente"*. Os registos com o nome do dono **são** clientes na tabela de clientes — cumprir uma metade viola a outra.

Não escolhas por ele, e não peças esclarecimento de mãos vazias. Leva o inventário e o mapa de dependências primeiro, e pergunta com o número ao lado: *"estes três estão na tabela de CLIENTES; este tem 9 mensagens e 2 tickets"*. A decisão passa a ser óbvia para o utilizador, e a pergunta custa-lhe uma linha em vez de uma investigação.

Sinais que obrigam a perguntar em vez de decidir:

- O candidato tem filhas com conteúdo real (mensagens, tickets, documentos, lançamentos).
- É nome de pessoa com documento formatado, mesmo que tenha entrado por um filtro de "teste".
- É um utilizador com papel operacional (contador, admin) e não um cliente — apagá-lo pode deixar a carteira dele órfã.
- O email pertence a uma conta que o utilizador usa a sério noutro sítio.

## Âmbito da aprovação

Uma aprovação cobre **os IDs que estavam na lista aprovada**, e mais nada. Candidato descoberto depois — durante a verificação, ou ao levantar a coorte — precisa da sua própria aprovação, mesmo quando a assinatura é idêntica à de um que já saiu. Juntar "mais um igual" a um lote já autorizado é apagar sem aprovação.

Se a pergunta de aprovação expirar sem resposta, **não apagues nada**: silêncio não é consentimento nesta classe de tarefa, porque a acção é irreversível. Fecha a sessão com o estado real ("a base segue com N registos, exactamente como estava"), o que ficou pendente, e a oferta de executar quando ele decidir.

## Formato da resposta ao utilizador

- Tabela do que saiu, com contagem por tipo. Nomes literais dos registos, não IDs.
- Tabela separada **da verificação independente**: cada coisa conferida e o resultado. É isto que sustenta a palavra "verificado".
- Totais antes → depois das tabelas principais, incluindo as que **não** mexeram.
- Diz o que mudou de plano a meio e porquê (ex.: a chave `SET NULL` que teria deixado órfãos). Sem isto o relatório parece um plano executado à letra, e o utilizador perde a informação que mais lhe interessa.
- Se um candidato ficou de fora por decisão dele, confirma explicitamente que está intacto e com as filhas todas.

## Antipadrões

- Apagar por `ILIKE`/padrão em produção porque "a lista é a mesma".
- Dar a lista por completa depois de um `ILIKE` por nome — registo de teste sem marca no nome só aparece na coorte.
- Acrescentar a um lote aprovado um candidato descoberto depois, por ter "a mesma cara".
- Confiar no cascade sem ler `delete_rule`, e reportar limpeza com órfãos deixados atrás.
- Usar a saída do script que apagou como prova de que apagou bem.
- Decidir sozinho qual metade de um pedido contraditório vale.
- Deixar o script de limpeza no repositório depois de correr.
- Reportar "limpo" depois de ler só uma das bases de uma aplicação multi-região.

## Skills relacionadas

- `devops/accontax360-worktree`: preparar worktree, correr suíte e build neste repo.
- `devops/operacao-host-windows`: formas de comando que passam o hook `dcg` de primeira.
