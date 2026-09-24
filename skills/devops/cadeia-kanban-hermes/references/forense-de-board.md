# Forense de board: o que outra sessão fez, e por que parou

Para «verifique o que aquele outro terminal está fazendo», «o board travou»,
«aquilo que pesquisamos deu em quê». O pedido parece ser sobre processo em
execução; a resposta quase sempre está no board, não na lista de processos.

## 1. Ler o board em SQL somente-leitura

`kanban_list` devolve dezenas de milhares de caracteres num board maduro e não
filtra por corpo nem comentário — inútil para procurar. Para **investigar**, leia
o SQLite direto; para **mudar** qualquer coisa, volte às ferramentas `kanban_*`
(elas mantêm eventos, dependências e reclaim coerentes).

O ficheiro fica em `%LOCALAPPDATA%\hermes\kanban.db` — não em `~/.hermes/`, que é
o palpite errado que faz concluir «não há board». Descubra antes de assumir:

```python
import glob, os
glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\hermes\**\*.db"), recursive=True)
```

Abra sempre em modo leitura, para não haver hipótese de corromper board que um
dispatcher pode estar a usar:

```python
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
```

Tabelas úteis: `tasks` (com `status`, `assignee`, `started_at`, `body`) e
`task_comments` (`task_id`, `body`, `created_at`). Datas são epoch — converta com
`time.localtime` antes de as mostrar.

Use o `sqlite3` do Python, não o binário de linha de comando: ele existe sempre,
não depende de instalação, e evita citação de aspas no MSYS.

## 2. Procurar por corpo e comentário, nunca só por título

O título descreve o **entregável**, não o método. Pesquisa de bibliotecas,
decisão de arquitetura e benchmark ficam enterrados no corpo do card ou no
comentário de fecho de um card chamado «Gráficos do Financeiro». Procurar
`biblioteca` nos títulos devolve zero e produz a conclusão falsa de que o
trabalho nunca aconteceu.

```sql
select id, status, title from tasks
 where body like '%recharts%' or body like '%bibliotec%';

select task_id, substr(body,1,400) from task_comments
 where body like '%bibliotec%' order by created_at desc;
```

O veredito costuma estar no **último comentário do confirmador**, não no `summary`
do produtor: é lá que está o que foi verificado por execução e o que ficou por
fazer.

## 3. Distinguir «a trabalhar» de «morto há dias»

Status `running` não prova atividade: sem dispatcher vivo nada devolve o card, e
ele fica `running` indefinidamente. Mas `tasks.started_at` também não decide — é
a primeira largada do card e sobrevive a retries, então card retomado agora
parece antigo. Pergunte a `task_runs`, que guarda a tentativa:

```sql
select t.id, t.status, r.started_at, r.ended_at
  from tasks t left join task_runs r on r.id = t.current_run_id
 where t.status = 'running';
```

`ended_at IS NULL` com `started_at` de minutos atrás é worker vivo. Run fechado,
ou `current_run_id` nulo, com o card ainda em `running`, é órfão.

A prova mais barata de todas é material: releia depois de um tick e veja se algo
mudou no disco ou no board. Trabalho real deixa rasto — `git status --porcelain`
com ficheiro novo, comentário novo no card, `updated_at` que avançou.

As três causas de board parado, por ordem de frequência:

1. **Assignee inexistente** — card em `ready` que nenhum dispatcher reclama (§0).
2. **Dispatcher em baixo** — nenhum card iniciado há horas, fila à espera.
3. **Worker morto a meio** — última linha do log com falha de conexão ao router.

São diagnósticos diferentes com correções diferentes; não reporte «parou» sem
dizer qual. Os logs por card ficam em `%LOCALAPPDATA%\hermes\kanban\logs\<id>.log`
e a última dezena de linhas costuma nomear a causa.

Falha de conexão ao router no log é **histórica**: teste o router agora antes de
a repetir como causa presente — se ele responde, o que falta é dispatcher, e
dizer o contrário manda o utilizador arranjar o que já está bom.

## 4. Relatar pelo que foi decidido, não pela mecânica do board

Abra pela **conclusão do trabalho** — o que se decidiu, o que mudou no produto, o
que ficou pendente. Ids, colunas e contagens entram depois, como suporte. Quem
perguntou quer saber em que pé está o módulo, não navegar no kanban.

Diga explicitamente o que ficou **parcial**: item que o confirmador aceitou com
ressalva é dívida viva e é a parte mais acionável da resposta.

## 5. Nunca destravar em lote sem confirmar

Desbloquear ou reatribuir dezenas de cards põe todos a despachar no tick
seguinte, contra cota real e contra o mesmo repo em paralelo (§3). Diga quantos
cards voltariam a correr e o que propõe mudar em cada classe, e espere a
resposta — mesmo quando a correção é obviamente certa.

A mesma cautela vale para o gateway: subir dispatcher com fila acumulada é, na
prática, o mesmo lote.
