---
name: cadeia-kanban-hermes
description: Use ao rotear trabalho pela cadeia de cards do Hermes.
metadata:
  hermes:
    tags: [kanban, orquestracao, dispatcher, gateway]
    category: devops
---

# Cadeia de cards do Hermes

Criar e rotear a cadeia produtor → revisor → testador → confirmador. O roteiro de
profiles e combos já vem no system prompt; este arquivo carrega o que só se
aprende despachando de verdade.

Para a fase de diagnóstico que costuma originar esses cards, veja
`references/auditoria-ui-medida.md`. Para fechar a cadeia — congelar, validar e
publicar o que vários workers escreveram em paralelo — veja
`references/publicar-trabalho-concorrente.md`. Para conferir achado de
isolamento entre tenants, países ou shards antes de repassá-lo a um produtor,
veja `references/achados-de-isolamento-multi-shard.md`. Quando a suíte dá
resultados diferentes na mesma árvore, veja
`references/suite-nao-deterministica.md`. Quando o trabalho nasce de
reclamação em linguagem corrente do dono do produto, veja
`references/relato-de-usuario-em-card.md`. Para reconstruir o que outra sessão
fez, ou por que o board parou, veja `references/forense-de-board.md`.

## 0. O assignee tem de existir

### Antes disso: confirme que o CORPO do card chegou inteiro ao banco

`kanban_create` pode gravar o `body` **truncado** — três cards nasceram com ~220
chars terminando literalmente em `...[truncated]`, enquanto cards criados noutra
sessão tinham 2400-3400 chars íntegros. O worker recebe o cabeçalho e nenhuma
especificação, gasta o run inteiro a adivinhar o escopo a partir de cards
vizinhos, e estoura o teto sem entregar. Nada no board acusa: o card parece
normal, o `kanban_create` devolve `ok: true`.

Depois de criar qualquer cadeia, meça o que ficou gravado:

```python
for tid in ids:
    b = con.execute("SELECT body FROM tasks WHERE id=?", (tid,)).fetchone()[0] or ''
    print(tid, len(b), '[truncated]' in b)   # True = card mudo, worker vai falhar
```

Corrija com `UPDATE tasks SET body=?` — esta escrita persiste (ao contrário de
`UPDATE ... status`, que o dispatcher reverte) — e comente no card avisando o
worker em curso para reler, porque ele já começou com a versão muda.

Quando um worker relatar «o corpo do card chegou truncado», **acredite e
verifique** em vez de tratar como desculpa: ele está a apontar defeito no seu
roteamento, e é a explicação mais barata que existe para um estouro sem entrega.

O dispatcher **ignora em silêncio** card com assignee desconhecido: ele fica em
`ready` para sempre e ninguém é avisado. Nome de skill não é nome de profile
(`sdlc-review` é skill; o profile é `auditordev`), e nome genérico plausível
(`worker`, `agent`, `qa`) não é profile nenhum. Confira contra a lista real
antes de criar:

```bash
~/AppData/Local/hermes/bin/hermes profile list
```

Ao herdar board de outra sessão, faça a varredura inversa antes de investigar
qualquer outra hipótese de parada: `select distinct assignee` no board contra
essa lista. Assignee que só aparece em cards parados é a explicação, e o card
não emite erro nenhum — parece esquecido, não quebrado.

O mesmo vale ao citar card: id escrito em prosa que nunca foi criado deixa o
achado órfão. Use o id devolvido por `kanban_create` e confirme no board.

**Worker também cria card — e erra o assignee com mais frequência que você.**
Um confirmador abriu card de correção com `assignee: "worker"` (a palavra genérica,
não um profile) e o pendurou como pai de si mesmo: o card ficou em `ready` cinco
dias sem nunca ser despachado, e congelou o próprio confirmador atrás dele. O
board não emite erro nenhum nessa situação. Depois de qualquer fechamento que
tenha gerado cards filhos, varra `assignee` contra a lista real — é uma consulta
e apanha o defeito antes de ele custar dias.

### Antes de recriar card órfão, procure o duplicado e re-meça o achado

Card órfão tenta duas armadilhas de uma vez. A primeira: **já pode existir outro
card para o mesmo achado**, em `blocked`, criado por outra sessão. Varra os
bloqueados por título parecido antes de criar — dois cards para o mesmo defeito
mandam um worker "consertar" código são.

A segunda: **o achado envelheceu**. Um defeito relatado há dias pode ter sido
corrigido de passagem por outra frente. Meça antes de recriar:

```bash
git show HEAD:<arquivo> | grep -n '<simbolo da correcao>'   # ja esta commitado?
git status --porcelain -- <arquivo>                          # vazio = publicado
```

Achado morto fecha com evidência, não com card novo. E desconfie da **contagem**
do relato tanto quanto do achado: "2 falhas de vitest no módulo X" acabou sendo 6
falhas, nenhuma no módulo X — quatro de uma renomeação e duas de banco fora do ar.

### Aposentar card órfão é com `kanban_block`, nunca com `UPDATE` no SQLite

`UPDATE tasks SET status='blocked'` parece resolver e **é revertido no tick
seguinte**: o dispatcher recomputa os prontos e devolve o card a `ready`, porque a
escrita crua não registra run nem evento de bloqueio. O card volta a aparecer
vivo e a próxima sessão reabre a investigação inteira.

Use `kanban_block(kind='needs_input')` com a razão escrita para humano, e
**confirme depois de dois ticks** que o status resistiu. O SQL direto serve para
ler e para `DELETE FROM task_links` — este sim persiste, porque o gate de
dependência só consulta os vínculos existentes.

### `tasks.started_at` é a PRIMEIRA largada, não a tentativa em curso

Um card retomado hoje, depois de bloqueado há cinco dias, continua com o
`started_at` original — e o painel anuncia "roda há 7426min". Ler esse campo como
idade da execução produz diagnóstico invertido: worker recém-largado vira órfão
antigo, e você "recupera" um card que estava trabalhando bem.

A tentativa real está em `task_runs`:

```sql
SELECT id, status, outcome, started_at, ended_at
  FROM task_runs WHERE task_id = ? ORDER BY id DESC LIMIT 1;
```

Run com `ended_at IS NULL` é a que está viva; a idade dela é a única honesta.
Confira também `tasks.current_run_id` — apontando para um run em aberto, o card
está mesmo em execução, por mais velho que o `started_at` pareça.

## 1. Confirmar o dispatcher ANTES de criar cards

```bash
~/AppData/Local/hermes/bin/hermes gateway status
```

Essa é a única prova de que existe dispatcher. **Não conclua que o gateway está
no ar casando nome de processo**: vários processos do Hermes (`tui_gateway.entry`,
kernels do execute_code, a própria TUI) casam com `python.exe` + "hermes" na
linha de comando sem serem o dispatcher. O processo certo é
`python.exe -m hermes_cli.main gateway`.

**Log de arranque não mede vida.** `gateway-starts.log` guarda quando o gateway
subiu, não se continua de pé: um registro de ontem é compatível com dispatcher
rodando há 24h e com dispatcher morto há 24h. Ler carimbo de largada como sinal
de vida produz o anúncio mais caro desta skill — «os cards não vão rodar» dito a
um usuário cuja fila está andando naquele instante.

Quando o `status` não estiver à mão, o board responde sozinho, mas **pergunte a
`task_runs`, não a `tasks`**: `tasks.started_at` é a primeira largada do card
(seção 0) e envelhece com ele. A prova de dispatcher vivo é run aberto recente:

```sql
SELECT MAX(started_at) FROM task_runs WHERE ended_at IS NULL;
```

Run aberto há minutos = dispatcher trabalhando agora. Nenhum run aberto, com
cards em `ready` esperando, é dispatcher morto — sinal mais confiável que
qualquer varredura de processo, porque mede o efeito e não o nome. `current_run_id`
preenchido no card confirma pelo outro lado.

E quando a conclusão for «está parado», **verifique antes de anunciar**: releia
depois de um tick e confira se algum card mudou de estado. Anúncio de fila morta
que o board desmente custa a mesma confiança que achado falso em auditoria. Para mutação use sempre as ferramentas `kanban_*`; para busca ampla
(por corpo, comentário ou assignee) o board se lê em SQL somente-leitura —
`references/forense-de-board.md`.

Card em `ready` sem dispatcher fica parado para sempre e o usuário espera por
nada. Ao entregar uma cadeia, **diga em uma linha se o gateway está no ar**.

Subir consome cota de verdade — pergunte antes quando houver fila acumulada.

`hermes gateway start` sem serviço instalado dispara prompts interativos e pede
UAC para criar a Scheduled Task; recusar a elevação cai no fallback da pasta
Startup e o gateway sobe igual. Confirme depois no log:

```bash
tail -25 ~/AppData/Local/hermes/logs/gateway.log
# kanban dispatcher [default]: spawned=N reclaimed=N crashed=N
```

## 1b. Estimativa de tempo é entrega obrigatória, e vem ANTES de executar

Ao montar uma cadeia — ou iniciar qualquer trabalho longo — entregue a
estimativa **no mesmo turno em que despacha**, sem o usuário pedir. Depois de
«criei os cards», o que ele quer saber é quando termina; responder isso só
quando perguntado transforma espera em ansiedade.

A estimativa vem de **medição**, nunca de chute. O board guarda o histórico, e
cada perfil tem ritmo próprio:

```python
import sqlite3, collections, os
db = os.path.expanduser("~/AppData/Local/hermes/kanban.db")
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
por = collections.defaultdict(list)
for a, s, c in con.execute(
    "SELECT assignee, started_at, completed_at FROM tasks "
    "WHERE completed_at IS NOT NULL AND started_at IS NOT NULL "
    "ORDER BY completed_at DESC LIMIT 60"):
    d = c - s
    if 30 < d < 20000: por[a].append(d)          # descarta orfao e reclaim
for p, ds in sorted(por.items()):
    ds.sort()
    print(p, len(ds), "mediana", ds[len(ds)//2]//60, "min | maior", max(ds)//60)
```

Para um card **em execução**, cronometre a tentativa atual, não o card:
`tasks.started_at` guarda a primeira largada e, depois de um retry, faz o
painel anunciar "roda há 1h01" quando a tentativa em curso tem um minuto —
prevendo estouro iminente para quem acabou de começar. O número honesto está em
`SELECT MAX(started_at), SUM(outcome='timed_out') FROM task_runs GROUP BY task_id`;
mostre também a contagem de estouros, porque é ela que decide se você corta
escopo ou deixa seguir.

Apresente **horário de término, não duração**. «Faltam 31 min» obriga o usuário
a fazer a conta e a refazê-la a cada consulta; «termina ~14:57» ele lê e decide
se espera ou sai. Dê o horário previsto **de cada etapa** (acumulando as
medianas em cascata) mais três totais: caso típico, pior caso, e o horário se
uma reprovação reiniciar o trecho. Quando o pior caso cruzar a meia-noite,
acrescente a data — horário sozinho vira promessa de hoje.

Apresente sempre **mediana e pior caso**, nunca um número só: a distribuição
é larga (um produtor com mediana de 38 min tem cauda de 150 min) e prometer a
mediana como prazo é prometer errado em metade das vezes.

Três coisas que a soma ingênua erra:

- **O dispatcher roda um card por vez.** Cards irmãos criados em paralelo
  executam em sequência — some as medianas, não maximize.
- **Conte a fila à frente.** `status IN ('ready','running')` de outras cadeias
  atrasa a sua, e o usuário não enxerga isso.
- **Reprovação reinicia o trecho.** Diga o custo de uma rodada de rework em vez
  de fingir caminho feliz; é o número que decide se ele espera ou corta escopo.

Diga também **o que você fará se estourar** (cortar escopo, avisar): teto de
runtime atingido devolve o card à fila e o relógio recomeça do zero.

## 1c. Teto de runtime estourado não significa worker parado — olhe o disco

`timed_out` no board parece fracasso, mas o worker pode ter produzido durante
todo o período e ter sido interrompido no meio de uma verificação. Antes de
concluir que ele girou em falso, procure a prova material:

```python
import os, time
base = r"C:\caminho\do\projeto"
corte = time.time() - 150*60
for raiz, dirs, arqs in os.walk(base):
    dirs[:] = [d for d in dirs if d not in ("node_modules", "dist", ".git")]
    for a in arqs:
        if a.endswith((".tsx", ".css", ".ts")):
            p = os.path.join(raiz, a)
            if os.path.getmtime(p) > corte:
                print(time.strftime("%H:%M", time.localtime(os.path.getmtime(p))), a)
```

Use Python, não `find -newermt`: em árvore com `node_modules` o `find` do MSYS
leva minutos e estoura o timeout da própria ferramenta.

Leia também os comentários do card — um worker disciplinado relata progresso
lá antes de morrer, e esse relato é o inventtitulo do que já está pronto.

**Na segunda vez que o mesmo card estoura, corte escopo em vez de reexecutar.**
Três rodadas de 90 min pelo escopo integral entregam menos que duas rodadas mais
um fechamento enxuto: o trabalho feito fica sem aceite e os auditores nunca
rodam. Comente no card autorizando fechar com o que existe, liste os três ou
quatro critérios que ainda valem, e mande o resto para os auditores — que
existem justamente para pegar o que faltou.

**Duas assinaturas diferentes de estouro, com tratamentos opostos.** Se o disco
tem arquivos novos e o card tem comentários de progresso, o worker produzia e
foi interrompido: autorize fechar com o que existe. Se rodou a hora inteira com
heartbeat e **não deixou uma linha no card**, o escopo não cabe no teto —
reexecutar igual estoura de novo. Corte a matriz antes de relançar: auditoria
visual de "5 rotas × 2 temas × 2 larguras" são 20 capturas com análise de
imagem em cada, e isso não termina em 3600s. Três rotas numa largura, num tema,
cabem — e um veredito honesto sobre três telas vale mais que vinte telas que
morrem com o processo.

**Existe uma terceira assinatura: estouro com zero produção.** Disco sem arquivo
novo, card sem comentário, workspace scratch vazio, dependência instalada mas sem
nenhuma linha que a importe. Aí não há o que preservar e não adianta autorizar
fechamento parcial. Antes de relançar pela terceira vez, **implemente você mesmo
se o escopo couber num turno seu** — e comente no card o que ficou pronto, para o
retry automático não duplicar o trabalho. Distinguir as três assinaturas custa
dois comandos (`git status --porcelain` e `grep` pelo símbolo da lib no repo) e
decide entre fechar, cortar escopo ou assumir.

**Ao assumir o trabalho de um card, releia o corpo inteiro antes de escrever —
não o título.** Assumir um card é onde é mais fácil acertar a técnica e errar o
alvo: o título diz a técnica («revelação por linha») e o corpo diz **onde** ela
se aplica («nos 5 capítulos da home», com o ficheiro e a função nomeados).
Implementar a técnica certa noutro sítio produz código que funciona, passa em
todos os portões e não cumpre o card. Antes de começar, liste os requisitos
numerados do corpo e, ao fechar, responda a cada um — essa é a única leitura que
apanha alvo trocado.

**Fechar card sob claim vivo:** `kanban_complete` é recusado enquanto houver
worker com claim ativo. A primeira ação é sempre **escrever a evidência num
`kanban_comment`**: comentário sobrevive ao próximo estouro e é o que impede o
retry seguinte de refazer trabalho pronto.

Mas **não espere indefinidamente o claim cair**. Num card que estoura em ciclo, o
dispatcher reclama-o no tick seguinte a cada estouro, e a janela sem claim nunca
aparece — esperar por ela deixa o card a girar e os filhos congelados. Quando o
trabalho está feito e verificado, o override de operador é o caminho legítimo
(a própria mensagem de recusa o indica):

```bash
hermes kanban complete --force <task_id> --summary "<uma linha>"
```

**Mantenha o `--summary` curto — uma linha.** O hook de segurança que inspeciona
comandos de terminal tem teto de avaliação na casa do segundo; `--summary` de
vários parágrafos faz a checagem estourar o tempo e o comando é recusado sem
chegar a correr ("could not complete safety evaluation"). A evidência longa já
está no comentário — a linha de comando carrega só o resumo.

Fechamento forçado salta o fluxo normal: **confirme que os filhos destravaram**
antes de anunciar que a cadeia seguiu. Espere um tick e verifique
`kanban_list(status='running')` — board vazio com filhos em `ready` é dispatcher
morto, não cadeia a andar, e o usuário fica a esperar por nada.

**Quando o teto foi você que apertou, diga isso.** Card com `max_runtime` menor
que os irmãos do mesmo lote estoura por configuração, não por lentidão do worker.
Registrar o erro de roteamento no fechamento evita que a próxima sessão conclua
que aquele perfil é lento e corte escopo que cabia.

E exija **veredito parcial escrito no card antes do fim do tempo**: comentário
registrado sobrevive ao SIGTERM, análise na cabeça do worker não.

## 1c-bis. A sua própria verificação compete com os workers pela máquina

Suíte pesada rodada por você enquanto há cards despachados **não é leitura
passiva**: ocupa os mesmos núcleos que o worker, e o teto de runtime dele conta
tempo de relógio, não de CPU. Cinco full-suites em paralelo levaram a suíte de
~60s para ~180s por corrida e estouraram duas vezes o mesmo card de teste, até
ele desistir — o worker não tinha defeito nenhum, faltava-lhe máquina.

O sintoma engana: o card morre por `timed_out` e a leitura natural é «o escopo
não cabe» ou «aquele perfil é lento», que leva a cortar escopo que cabia.

Antes de lançar medição longa, veja se há card em execução
(`kanban_list(status='running')`); havendo, ou espere, ou lance uma corrida só.
Quando o estouro acontecer e você tiver rodado carga em paralelo, **escreva no
card que a causa foi contenção sua** — senão a próxima sessão herda um veredito
falso sobre a capacidade daquele perfil.

Regra geral: quem orquestra também consome a máquina que empresta. Trabalho de
verificação pesada é para a janela em que o board está parado.

## 1d. Meça você mesmo o número alegado — de produtor E de auditor

`kanban_complete` é **autodeclaração**. Um worker fechou um card dizendo
"123 falhas de alvo de toque levadas a 0, verificado em 5 larguras"; a medição
independente do orquestrador, no mesmo minuto, encontrou 8 falhas em todas as
rotas. O worker não mentiu — mediu a árvore errada.

### Diga em que ambiente mediu, sempre, sem esperar a pergunta

Medir na demo e relatar como se fosse a conta do usuário é a falha que mais
custa confiança — e ela não parece mentira de dentro: os números são reais, só
vieram de dados sintéticos de uma empresa fictícia. Toda afirmação de
verificação carrega o ambiente: conta real × demo × seed local, e qual conta.
O que você **não** verificou entra no fechamento com a mesma clareza do que
verificou.

Quando o usuário acusar invencionice, separe as duas coisas em vez de defender
as duas ou recuar das duas: o que foi medido de fato (e onde), e o que foi
extrapolado indevidamente. Conceder a parte procedente e sustentar a parte
medida é o que devolve credibilidade; «tem razão em tudo» joga fora evidência
boa, e «mediu sim» sem dizer onde repete o erro.

### Reveja veredito alheio medindo, e reveja o seu próprio medidor

Ao auditar entrega de outro worker, verifique também o **instrumento** antes do
número: um medidor com bug produz achado espetacular e falso, e repassar isso
manda corrigir código são. Sinal barato de instrumento quebrado é resultado
degenerado — razão exatamente 1.00, contagem idêntica em telas diferentes, zero
com universo zero. Antes de escrever o card, valide o medidor contra um caso de
resposta conhecida.

**A causa quase sempre é a mesma: workspace `scratch`.** O worker trabalha em
`~/AppData/Local/hermes/kanban/workspaces/<task_id>` e roda build e verificação
lá. Se a correção precisa valer na árvore compartilhada que o usuário abre, o
card tem de dar o caminho absoluto **e** exigir que a medição de aceite rode
nele.

Quando a alegação for numérica e verificável (contagem, tamanho, tempo,
contraste), reproduza antes de repassar adiante:

- refaça o build na árvore compartilhada, para não medir `dist/` velho
- rode a mesma consulta que o card pediu, com os mesmos parâmetros
- compare com o número alegado antes de deixar o card seguir

**Leia o total da suíte, não a palavra `passed`.** `Tests 2 failed | 3220 passed (3222)` reporta-se como «3220/3220» com uma leitura desatenta, e o número vira verde autodeclarado que um auditor derruba depois. O total é o parêntese; quando ele não bate com os que passaram, existem falhas e elas têm de ser classificadas (regressão sua × ambiente) antes de o número seguir adiante. Vale para o seu próprio relato tanto quanto para o do worker — repassar portão verde inexistente custa mais credibilidade que a falha original.

Discrepância não é má-fé: anote a hipótese (árvore errada, dist anterior,
seletor diferente), diga o que **de fato** ficou correto — quase sempre parte
ficou — e abra um card de correção só do que resta. "Você corrigiu o rodapé e o
aviso de cookies; falta a barra do topo" faz o worker seguinte acertar de
primeira; "reprovado" faz ele refazer tudo.

### Em trabalho visual, portão verde não é prova de efeito

Para card de animação, 3D ou pós-processamento, `tsc` e `build` verdes provam
apenas que o código **compila**. O modo de falha dominante é outro: o efeito é
instanciado, roda todo frame, custa GPU e **não produz pixel nenhum**. Um
threshold acima do pixel mais claro da cena, um hook montado que nunca dispara,
uma lib instalada e nunca importada — tudo passa em qualquer portão estático.

Exija no corpo do card, e verifique você mesmo antes de repassar:

- **Número que muda no tempo**, não presença de símbolo no DOM. Amostrar
  `getComputedStyle(el).transform` a cada 100ms durante a transição distingue
  «animou e chegou» de «nunca saiu do lugar»; uma leitura única após o repouso
  não distingue.
- **Para efeito de imagem, captura comparada com pergunta explícita** ("há halo
  difuso ao redor dos traços ou são linhas secas?"). "Parece brilhante" confunde
  brilho de fundo com efeito aplicado.
- **Confira `prefers-reduced-motion` no navegador da medição** antes de concluir
  que o efeito não existe — a guarda desliga tudo e produz falso negativo.

Quando o worker entrega "efeito X visível" e a tela desmente, a causa costuma ser
parâmetro fora da faixa útil da cena, não código errado. Meça a grandeza real
(luminância, distância, duração) e escreva o número no card: "o threshold está
em 0.9 e o pixel mais claro da cena é 0.57" corrige de primeira, "o bloom não
aparece" gera outra rodada de chute.

**O veredito de um auditor passa pela mesma régua — inclusive quando ele APROVA.**
Achado "não-bloqueante" pendurado numa aprovação é o que mais escapa à medição,
justamente porque não trava nada; e a contagem dele erra como qualquer outra.
Meça a **extensão** antes de corrigir: "o rótulo repete em três níveis" era
colisão em 3 de 10 locales — os outros 7 já distinguiam, e corrigir os 10
reescreveria copy boa. Veredito vem com números
("vão de 200px", "nenhum preço na tela") e eles erram tanto quanto os do
produtor — um vão medido em 200px era de 332px, e o "nada aparece acima da
dobra" era o card visível com só o preço fora. Repassar número errado é pior que
repassar nenhum: o produtor encolhe a distância errada e o defeito real sobrevive
à correção.

Meça antes de escrever o card de correção e **escreva os seus números no corpo,
dizendo explicitamente que substituem os do veredito** — senão o produtor lê os
dois e escolhe o mais fácil. Registre a correção também no card do auditor: o
confirmador vai comparar a entrega com o veredito original.

O que sobrevive do veredito, mesmo com número errado, é a **direção**: o auditor
olhou com olhos de cliente e a falha costuma existir. Corrija a medida, não
descarte o achado.

Auditor honesto devolve também **achados que ele não conseguiu confirmar**
("a captura do tema claro veio escura — pode ser bug ou artefato"). Esses não
viram card de correção: vão como comentário no card do **testador**, que mede ao
vivo. Transformar suspeita em ordem de correção faz o produtor mexer em código
so para calar um artefato de medição.

## 1e. Card que estourou volta a rodar sozinho — não abra substituto sem gate

Após `timed_out`, o dispatcher **requeue o card automaticamente** e ele volta a
`running` com o corpo original intacto. Se você, vendo o estouro, abrir um card
novo para a parte que faltou, passam a existir **dois workers com a mesma
instrução**, em workspaces isolados, editando o mesmo arquivo. Quem fechar por
último sobrescreve o outro.

**`kanban_unblock` tem o mesmo efeito.** Desbloquear um card para o fechar entrega-o
ao dispatcher no tick seguinte, e um worker novo nasce antes de você escrever o
fechamento. Se a intenção é fechar, feche direto; só desbloqueie o que realmente
deve voltar a executar.

`kanban_link` **não é retroativo**: se o dispatcher já tirou o card de `ready`
(tick de 60s), o gate de dependência chega tarde e os dois rodam mesmo assim.

Antes de abrir card de continuação, verifique o status do card que estourou:

```python
con.execute("SELECT status FROM tasks WHERE id=?", (tid,)).fetchone()
# 'running' -> ele ja reiniciou; NAO abra substituto, ou abra com parents=[tid]
#              na MESMA chamada kanban_create, nunca com kanban_link depois
```

Quando a colisão já aconteceu, não tente desfazer: comente no card mais novo
mandando **medir antes de editar** (se o outro já resolveu, fecha sem trabalho),
manter o diff mínimo e localizado, e listar os arquivos tocados no fechamento.

O schema real é `task_links(parent_id, child_id)`, `task_comments`, `task_runs` —
não `deps` nem `comments`.

## 1f. Nunca declare trabalho "não feito" com base em `git diff`

`git diff --stat` mostra só ficheiros **rastreados**. Um diretório novo criado pelo
worker aparece como `??` e é invisível ao diff — concluir "não foi tocado" a partir
daí acusa o worker de não entregar o que ele entregou.

Antes de contestar entrega, sempre:

```bash
git status --porcelain      # inclui os ?? que o diff esconde
```

E não repita o número do card como se fosse medição nova: re-meça no build atual.
O defeito pode ter sido corrigido entre a medição original e a leitura.

## 1g. Pai que não vai fechar trava os filhos — remova o vínculo

O gate de dependência libera o filho quando todos os pais estão `done`. Qualquer
outro estado terminal — `archived`, `blocked`, `triage` — **não conta como done** e
prende o filho em `todo` para sempre. Bloquear um card é, portanto, congelar a
cadeia inteira atrás dele, e ninguém é avisado.

Ao bloquear ou cancelar um card que já tem filhos, apague o vínculo:

```sql
DELETE FROM task_links WHERE parent_id='<aposentado>' AND child_id='<filho>';
```

Depois confirme que o filho saiu de `todo` no tick seguinte — se não saiu, sobrou pai.

**Auditor órfão de pai aposentado é armadilha de duas pontas.** Bloquear um
produtor deixa o revisor dele pendurado, e esse revisor costuma ser pai do
testador — a cadeia inteira congela em `todo` sem emitir erro nenhum; o board
mostra tudo «esperando» como se fosse normal. Ao aposentar produtor, percorra os
filhos dele e decida um a um: religar a outra frente ou arquivar.

**Reaproveitar auditor exige reescrever o CORPO, e o título continua a mentir.**
`UPDATE tasks SET body=?` persiste, mas o título antigo permanece visível e o
worker lê-o primeiro. Abra o corpo com uma linha explícita — «o título está
desatualizado, este card revisa X, ignore o título» — mais o SHA a revisar. Sem
isso o auditor procura o trabalho do card antigo, não encontra, e gasta o run a
tentar reconciliar título com corpo.

Dê-lhe também a instrução de revisar o **commit**, não a working tree
(`git show <sha>`, `git diff <base>..<sha>`): com irmãos a correr no mesmo
diretório, ficheiro modificado não-commitado é trabalho alheio e não entra no
veredito dele.

**Ao redividir um card em cards menores, ligar os novos ao filho é metade do
trabalho.** Card novo sem `parents` apontando para o revisor faz o trabalho e o
resultado morre ali; card velho ainda pendurado no revisor o mantém congelado. As
duas metades são obrigatórias: `kanban_link` dos novos para o filho, `DELETE` do
vínculo do aposentado. Confira a lista de pais do filho depois de mexer — é a
única leitura que mostra a cadeia como o dispatcher a vê.

### Aposentar um card em `goal_mode`

Card com `goal_mode` não fecha por decisão sua: o juiz de conclusão compara a
entrega com o objetivo escrito no corpo e **recusa** `kanban_complete` quando o
objetivo não foi cumprido — inclusive quando você redividiu o escopo e o card
perdeu o propósito. E `kanban_block` nesses cards só aceita `dependency` ou
`needs_input`; `capability` é rejeitado.

Então o caminho para aposentar é `kanban_block(kind='needs_input')` com a razão
escrita para humano («não retentar, escopo migrou para t_x e t_y, ação: arquivar»),
mais o `DELETE` do vínculo. Não tente maquiar o resumo para o juiz aceitar — a
recusa dele está certa e o registro honesto é o que impede a próxima sessão de
redespachar o card.

## 1h. Crie a cadeia INTEIRA antes de deixar o dispatcher rodar

O gate de dependência só vale para vínculos que existem **no momento do tick**. Se o
último card da cadeia (confirmador) tem um pai `done` e você ainda não criou os cards
de correção, o dispatcher despacha ele na hora — e ele julga um estado obsoleto.

Aconteceu: testador fechou com uma reprovação, o confirmador disparou no mesmo tick,
e só depois nasceram o card de correção e o de re-teste. O confirmador ficou 18 min
rodando sobre uma árvore que já não era a final.

Regra: ao receber reprovação, **crie correção + re-teste e ligue-os ao confirmador
ANTES de qualquer outra coisa**. Se o confirmador já estiver `running`, comente
mandando encerrar sem veredito — veredito prematuro erra nos dois sentidos.

## 2. Procurar card órfão antes de supor que algo está trabalhando

Gateway que morre deixa o card em `running` indefinidamente — não há timeout que
o devolva sozinho enquanto não houver dispatcher vivo. Cheque
`kanban_list(status='running')` e compare `started_at` com o relógio: `running` há
muitas horas é órfão, não trabalho em curso. O próximo `gateway start` o reclama
e o `current_run_id` incrementa.

## 2b. Card que deu `gave_up` pode ter o trabalho feito

`gave_up` e `blocked` por timeout registram que **o worker** estourou o relógio,
não que o trabalho não aconteceu. Os heartbeats costumam descrever entrega real, e
parte dela pode já ter sido commitada e publicada por você ao fechar outra cadeia.

Antes de desbloquear ou redespachar, confira **em disco e no commit publicado**
item por item do corpo do card:

```bash
grep -rlE '<marcador do item>' <dir de fontes>
git show <commit-em-producao> --stat | grep -E '<arquivo esperado>'
```

Redespachar um card cujos itens já estão no ar faz o produtor reescrever por cima
de código que já serve clientes. Quando sobrar só parte do escopo, **mova o resto
para um card novo de uma frente** e deixe no card antigo um comentário dizendo o
que está feito, onde está publicado, para onde foi o resto e que a ação correta é
`kanban_complete` — `kanban_unblock` devolve o card a `ready` e o dispatcher o pega
de novo sem ler a sua intenção.

## 2b-bis. Card bloqueado por assignee inválido fica bloqueado

Quando um card foi bloqueado porque o profile não existe e a revisão que ele pede
já tem cadeia correta, **não o desbloqueie**: `kanban_unblock` o devolve a `ready`
e duplica revisão de código já publicado. Comente no card por que o bloqueio deve
permanecer — senão o próximo a varrer o board o desbloqueia por parecer esquecido.

Card assim costuma carregar contexto que a cadeia correta não tem (achados
adjacentes, limites declarados, decisão de produto em aberto). Antes de o deixar
de lado, **verifique se os achados dele continuam vivos**: um deles pode já ter
sido resolvido por outro worker, com a decisão documentada no próprio arquivo.
O que continuar em aberto e exigir julgamento humano, escreva no fechamento.

### Veredito de testador sem evidência colada audita-se pelo rasto em disco

«PASSA» com invariantes descritas em prosa, sem uma linha de saída de comando nem
captura, costuma significar que a verificação ao vivo não aconteceu — e o card de
teste existe justamente para ela. O rasto é barato de conferir: a sessão do worker
vem no `metadata` do run (`worker_session_id`), e uma verificação visual real
deixa workspace de navegador e ficheiros de imagem com data dentro da janela em
que ele correu.

Ausência dos dois não reprova o trabalho — reprova o **veredito**. Refaça a
medição você mesmo antes de deixar o confirmador julgar sobre um aceite vazio, e
escreva no card do confirmador que o degrau anterior foi fraco: ele decide com
mais rigor quando sabe que a rede de segurança tinha um furo.

## 2c. Bloqueio relatado pelo testador é achado, não ruído

Exija no card de teste que o worker escreva **NÃO TESTÁVEL com o erro colado**
quando não conseguir abrir a tela, em vez de «verificado». Relato honesto é o que
expõe dívida; alegação vaga a esconde e ainda carimba como visto o que ninguém viu.

Quando o mesmo bloqueio impede a verificação em mais de um card, ele deixou de ser
contratempo de ambiente e virou defeito próprio: diagnostique a causa e abra cadeia
para ela, pendurando a verificação visual acumulada no card de teste dessa cadeia —
destravado o acesso, paga-se a dívida inteira de uma vez.

## 2d. Resumo de worker chega truncado — leia o card inteiro

A notificação de conclusão corta o resumo no meio. Quando o corte cai dentro de
uma ressalva («Nota sobre X:...»), essa ressalva é justamente o que precisa de
parecer: `kanban_show(task_id=...)` traz `summary` e `metadata` completos.

Worker que sinaliza «este caso não segue o padrão do card» costuma estar certo e
a apontar erro no **seu** card, não regressão no código. Verifique antes de
tratar como pendência, e escreva a correção no card do confirmador — senão ele
herda a sua expectativa errada e reprova entrega correta.

## 3. Cards paralelos no mesmo repo colidem

### DB do kanban trava sob workers ativos — escreva o aviso antes de despachar

Com dois ou mais workers a correr, o SQLite do board fica sob contenção e
`kanban_comment` chega a expirar (420s) sem gravar nada; `sqlite3` direto devolve
`database is locked` mesmo com `busy_timeout` de 25s. O efeito prático é grave:
**é justamente enquanto o worker trabalha que você não consegue corrigir o rumo
dele**, e a correção só entra depois de ele morrer.

Consequências para o método:

- Ponha toda a orientação no **corpo do card**, antes do despacho. Comentário
  posterior é canal de recurso, não de instrução.
- Descobrindo alvo errado com o worker em curso, tente comentar uma vez; se
  expirar, **não force escrita** — board corrompido é pior que um run perdido.
  Guarde o diagnóstico e grave-o assim que a DB liberar: crash ou estouro do
  worker abre a janela, e o retry automático já nasce a ler o comentário.
- Leitura continua barata: abra sempre `file:...?mode=ro` para consultar estado,
  que não disputa o lock de escrita.

`workspace_kind='scratch'` **não isola o repo do projeto**: cards despachados em
paralelo editam a mesma working tree, no mesmo branch, sem branch por card. Três
devs simultâneos nos mesmos arquivos perdem trabalho um do outro em silêncio.

**Dois cards que tocam o mesmo ficheiro não se despacham em paralelo — ponto.**
Não basta declarar território no corpo: dois produtores no mesmo
`Ecom360Experience.css` correram 90 min cada, com heartbeat até ao fim, e
entregaram **zero linhas** — nenhum ficheiro novo, nenhum comentário no card, o
`git diff` idêntico ao commit de partida. Duas horas e meia de cota por nada, e o
auditor reprovou a frente inocente por contaminação da árvore.

O teste antes de despachar é mecânico: liste os ficheiros que cada card vai
editar; havendo interseção, encadeie por `parents` em vez de criar irmãos. Custa
a soma das medianas em vez do máximo — e a soma de dois cards que entregam vale
infinitamente mais que o máximo de dois que colidem.

**Antes de despachar qualquer cadeia nova, a árvore tem de estar limpa.**
`git status --porcelain` vazio. Trabalho em curso não-commitado vira
"contaminação" no veredito do auditor seguinte, que reprova a entrega correta
por causa do lixo alheio. Commit de checkpoint marcado `wip(...)` no assunto,
com o que falta escrito no corpo, resolve — e dá ponto de partida limpo ao
retry.

Antes de despachar mais de um card que toca o mesmo repo, escolha uma das duas:

- `workspace_kind='worktree'` com `workspace_path` absoluto, ou
- comentar em **cada** card as regras de convivência abaixo.

Regras de convivência (colar no card, não presumir que o worker sabe):

- Proibido `git reset --hard`, `git stash`, `git clean`, `git checkout .` — apagam
  o trabalho não-commitado dos irmãos que estão rodando agora.
- `patch` em vez de `write_file` em arquivo compartilhado; reescrever um arquivo
  grande inteiro mata a edição que outro worker fez entre sua leitura e sua escrita.
- Fronteira de escopo explícita: nomeie o que este card é dono e o que pertence a
  qual card irmão, com a instrução de não invadir.
- Conflito que o worker não resolve com segurança → `kanban_block` com arquivo e
  linha, nunca sobrescrever.

Liste os ids dos cards irmãos no comentário: worker não enxerga contexto de irmão.

### Arquivo que volta a «modified» sozinho: worker vivo, não fantasma

Restaurar um ficheiro e ele reaparecer modificado em menos de um minuto é worker
rodando agora com `workspace_kind='scratch'` a editar a árvore compartilhada.
Diagnostique pelo efeito, não por lista de processos (dezenas casam com
`python.exe`): grave o `mtime`, aguarde, releia. Se o `mtime` **não** mudou mas
o git ainda diz `M`, a diferença é outra — vá ao `git diff` real antes de
acusar ninguém.

Pare pelo board (`kanban_block(kind='needs_input')` no card culpado), e registre
no motivo que o card foi criado `scratch` mas alcançava o repo — senão a
próxima sessão o desbloqueia por parecer esquecido. `kanban_list(status='running')`
vazio não encerra a hipótese: processo órfão de gateway morto continua escrevendo
sem card vivo no board.

**`git checkout -- <ficheiro>` não restaura o que está untracked**, e num repo com
irmãos rodando pode apagar trabalho não-commitado de outro card. Prefira reescrever
a linha específica com `patch` depois de ler o `git show HEAD:<ficheiro>`.

### «modified» sem diff é CRLF, não edição

Em Windows, escrever ficheiro por API de alto nível grava CRLF e o git marca `M`
com `git diff` vazio. Não é worker alheio nem conteúdo perdido: normalize com
`git add --renormalize <ficheiro>` em vez de `checkout`, que descartaria edição
real de um irmão junto com o ruído. Antes de concluir qualquer das duas coisas,
compare `git diff <ficheiro>` (vazio ⇒ só fim de linha) com
`git diff --stat` (linhas contadas ⇒ conteúdo mesmo mudou).

### Verifique o ÍNDICE antes de fechar commit em árvore compartilhada

`patch` seguido de `git add` não é atômico. Se um worker reescrever o ficheiro
entre os dois, o que entra no índice é a versão dele — idêntica ao `HEAD` — e o
git **não registra alteração nenhuma** para aquele ficheiro. O commit sai com
mensagem convincente e leva só os ficheiros novos (o teste), deixando no repo um
teste sem o código que ele testa. Nada acusa: `git commit` devolve exit 0 e o
resumo de ficheiros é curto demais para chamar atenção.

Pior, a suíte confirma o engano: ela corre na **working tree**, que tem a
correção, enquanto o repo não tem. Verde medido no lugar errado.

Antes de fechar qualquer commit num repo com irmãos rodando, leia o índice — não
a árvore:

```bash
git show :<caminho> | grep -n '<símbolo da correção>'   # índice, não working tree
git diff --cached --stat                                 # o ficheiro está na lista?
```

E depois do commit, confirme no `HEAD`:
`git show HEAD:<caminho> | grep -c '<símbolo>'`. Ficheiro que você editou e não
aparece no `--stat` é o sintoma — não é "o git otimizou", é a sua edição perdida.

A validação por mutação também tem de correr **sobre o código commitado**, não
sobre a árvore: mutar, ver vermelho e restaurar prova que o teste guarda o que
está no repo. Para desfazer a mutação, aplique a substituição **inversa** com
`assert` da contagem — `git checkout -- <ficheiro>` é bloqueado pelo `dcg` e, num
repo com irmãos, descartaria trabalho não-commitado alheio junto.

### Território sem exceção de destrave vira deadlock

A regra «não toque nos arquivos do outro» protege contra sobrescrita, mas trava a
equipe quando a correção de um lado depende de **poucas linhas** do outro. Uma
renomeação de chave de i18n migrou 11 locales e a interface de tipos; sobraram 3
chamadas da chave antiga num componente de território alheio, e o build ficou
vermelho **para os dois**. O worker fez o certo pela regra — `kanban_block` e
esperar autorização — e a autorização nunca chegou, porque do outro lado havia
outro agente igualmente proibido de agir. Ninguém avançou.

Ao declarar territórios, escreva sempre a exceção junto:

- **Correção mecânica de 1-5 linhas para destravar build compartilhado é
  PERMITIDA** em qualquer território, desde que registrada no canal — renomear
  símbolo, ajustar import, propagar chave. Não é decisão de design, é conserto de
  referência quebrada.
- Qualquer mudança de **comportamento** continua exigindo acordo.

Sem essa cláusula, quem migra um símbolo compartilhado fica refém de quem tem o
último chamador — e um build vermelho bloqueia todo mundo enquanto dois agentes
educados esperam um pelo outro.

**Quem quebra o símbolo é dono da migração inteira.** Antes de renomear chave,
tipo ou export compartilhado, `grep -rn <símbolo antigo> src/` e conte os
chamadores. Se algum cair em território alheio, ou você tem a exceção acima, ou
não comece a migração — deixá-la pela metade é pior que não a fazer.

Tratamento de colisão no teste (quando a prevenção acima falhar):
Se um testador rejeitar uma frente limpa porque o `tsc` ou `vitest` quebrou com erro de sintaxe (ex: `Unexpected }` ou tags desbalanceadas) introduzido por um card paralelo, **não reverta nem condene a frente original**. Crie um card relâmpago de `Dev` encadeado à falha do testador, instruído unicamente a limpar o resíduo sintático e reparar a compilação paralela da árvore, seguido de nova tarefa de re-validação. Roteie a limpeza e o polimento sintático para frente, preservando o trabalho lógico dos workers paralelos.

Enquanto os workers rodam, o disco está vivo: qualquer validação que você faça na
working tree mede um estado que muda embaixo de você. Para congelar e publicar,
`references/publicar-trabalho-concorrente.md`.

## 3b. "Finalizar" não diz qual ambiente

"Deixar pronto", "subir para eu testar" e "finalizar o módulo" admitem localhost e
produção — riscos opostos, e publicar é caro de desfazer. Pergunte em uma linha
antes de empurrar, sobretudo quando as auditorias obrigatórias ainda não rodaram.
Se publicar assim mesmo for a decisão, diga no fechamento quais gates ficaram de
fora, para a dívida ficar assumida em vez de parecer cumprida.

### Pendência de board não retém publicação já verificada

A regra acima manda perguntar o ambiente — ela **não** autoriza segurar trabalho
pronto à espera de burocracia do quadro. Card que desistiu por estouro de relógio,
filho congelado atrás de pai bloqueado e degrau cuja medição você já refez são
estado do board, não risco no código. Quando a substância da verificação está
feita (suíte completa, portões estáticos, mutação vermelha/verde, build de
produção), o que falta é registro.

O modo de falha é oferecer um menu — «recrio o card do testador ou libero o
confirmador?» — enquanto a correção continua fora do ar. O dono lê isso como
trabalho parado, e ele está certo: nada do que o menu decide muda o que será
publicado.

Então: complete o que depende só de você, e feche o turno com **uma pergunta
fechada** («publico?»), nunca com escolha entre caminhos internos. Se a resposta
já veio condicionada («publica se estiver funcional»), a condição é sua para
verificar — rode o build de produção e publique, sem voltar a perguntar.

Ao explicar o atraso a quem não acompanha o board, diga na ordem que importa: o
que muda para o usuário, o que já está provado, e só então o que faltava. Nomear
cards e estados como justificativa soa a desculpa de processo para quem só quer
saber se a conta que vence hoje ainda diz «Vencido».

## 4. Reverificar os próprios achados antes do produtor começar

Achado errado no corpo do card vira reimplementação do que já existe. Depois de
escrever a cadeia, confira no código os achados que sustentam cada card; quando
um cair, **comente a correção no card** em vez de deixar o worker descobrir
sozinho. Vale principalmente para "não existe X" — ausência é a conclusão mais
fácil de errar.

Duas verificações custam segundos e derrubam a maioria dos achados falsos:

```bash
git show <commit-em-producao>:<arquivo> | grep -n '<simbolo>'   # já está publicado?
ls ~/AppData/Local/hermes/kanban/workspaces/ | grep <id>        # o card existe?
```

### Confirme que o artefato apontado pelo card está VIVO

**E que o defeito ainda existe, e que está no ficheiro que você nomeou.** Estas
são três verificações distintas, e falhar qualquer uma delas queima o run
inteiro do produtor com a mesma aparência de trabalho normal:

```bash
grep -rn '<classe ou simbolo do defeito>' components/ pages/   # ainda existe?
grep -rn '<termo do elemento>' <ficheiro que o card nomeia>     # e neste ficheiro?
```

Zero na primeira é **defeito já morto**: feche com evidência em vez de mandar
corrigir. Zero na segunda é **ficheiro errado no card**: o elemento existe, mas
noutro sistema — e o worker vai auditar a tecnologia errada (`z-index` onde o
eixo é `depthWrite`) sem nunca tocar o defeito.

O erro nasce de rotear a partir da sua própria memória: depois de criar um
componente, a suposição de que tudo o que é visualmente vizinho vive nele custou
três cards seguidos. **Grepe o código antes de escrever o corpo, inclusive —
sobretudo — quando o trabalho a corrigir é seu.**

Quando o worker responder que o alvo do card é código morto, que o defeito não
existe ou que o ficheiro está errado, ele achou defeito no seu roteamento, não no
produto — confirme por execução e reescreva o card, em vez de tratar como desvio
de escopo. Recusa fundamentada é o comportamento correto e deve fechar o card
como cumprido na origem.
Antes de mandar auditar ou corrigir um componente, prove que ele entra na árvore
renderizada — não que existe no disco. Um ficheiro importado e nunca usado no JSX
(ou um módulo exportado que ninguém chama) passa em qualquer `grep` de existência
e consome o run inteiro do produtor: ele audita `!important`, contraste e z-index
de código que não pinta um pixel, e o defeito real fica intacto. Grepe o ponto de
**uso** (`<Componente`, a chamada com parênteses), nunca o import.

Quando o worker responder que o alvo do card é código morto, ele achou defeito no
seu roteamento, não no produto — confirme e reescreva o card em vez de tratar
como desvio de escopo.

Nunca escreva "o card X nunca existiu" ou "isto está em produção" sem rodar as
duas — e vale igual para a afirmação inversa, "isto já está commitado e revisado
em `<sha>`". Prove com `git show --name-only <sha> | grep <arquivo>` antes de a
escrever num handoff: atribuir ficheiro a commit que não o toca faz o revisor
seguinte tratar como já auditado código que ninguém leu, e o erro só aparece se
alguém desconfiar. `kanban_list` tem limite e paginação: não encontrar um id ali **não** prova
ausência. E um defeito relatado por um revisor pode já ter sido corrigido por
outro card entre o relato e a sua leitura — o achado envelhece.

Quando o card manda "investigue antes de corrigir" e a evidência contraria o
pedido, **o produtor está certo em recusar**. Reverifique você mesmo por execução
(não releia o argumento dele: rode), e se ele tiver razão, comente a correção no
card do revisor — senão o revisor procura código que deliberadamente não existe e
reprova entrega correta. Card cujo corpo descreve trabalho diferente do entregue
envenena a revisão inteira.

### Gravidade errada desvia a correção tanto quanto premissa errada

Achado de auditor chega com uma severidade anexada («APAGA», «vaza», «quebra em
produção») e essa severidade é uma **segunda afirmação a verificar**, não um
rótulo a repassar. Rode o passo seguinte ao que o auditor parou: a chamada que
viria depois costuma ter guarda própria que muda a classe do risco (destrutivo →
diagnóstico), e o inverso também acontece — um achado descrito como colisão de
chave pode terminar em entrega de dado ao tenant errado.

Escreva a gravidade corrigida no card com a evidência da execução. Severidade
inflada faz o produtor desenhar proteção de emergência onde já existe defesa em
profundidade; severidade subestimada faz corrigir o sintoma e deixar o vazamento.

### Prove o achado com um probe executável, não com leitura

Para achado de biblioteca ou função pura, um arquivo de ~10 linhas que importa o
código **real** e substitui só a fronteira de I/O por dublê em memória decide em
segundos, sem tocar banco:

```bash
cd <pacote> && cat > ./probe.ts <<'EOF'
import { alvo } from './src/<caminho>';
// dois dublês isolados = dois shards que não se enxergam
EOF
npx tsx probe.ts 2>&1 | tail -5; rm -f ./probe.ts
```

Crie e rode o probe **dentro do pacote**, e apague no mesmo comando: ferramenta
nativa não resolve caminho de diretório temporário do MSYS, e arquivo esquecido
na raiz é varrido por `tsc`/`eslint` e derruba o portão dos irmãos.

Quando o probe falhar, leia a mensagem antes de comemorar: erro de import
(`Cannot read properties of undefined`) prova que o probe quebrou, não que a
guarda barrou. Reescreva-o contra o entrypoint real até a falha vir com a
mensagem da guarda.

## 5. Encadear as auditorias obrigatórias

Quando os cards tocam dado pessoal, `auditorsec` e `auditorlgpd` entram em
paralelo **depois** da revisão de código e **antes** do teste. Use `kanban_link`
para que o card de teste espere as quatro auditorias — criar o teste antes das
auditorias deixa a ordem errada e o `parents` inicial não basta.

Escolha o revisor pelo **que está em risco**, não pelo tipo de arquivo: quando o
que pode quebrar é isolamento (de tenant, de país, de shard), o card vai para
`auditorsec` mesmo sendo script, seed ou build — `auditordev` revisa qualidade de
código e deixa passar o que só se enxerga olhando como ameaça.

O confirmador precisa de critério explícito: ganho de UX ao custo de isolamento
de tenant é reprovação, por melhor que a tela tenha ficado.

**Audite a cadeia depois de cada fechamento.** Card criado por um worker (um dev
que abre o próprio card de revisão) nasce fora da cadeia de quatro papéis e fecha
sem testador nem confirmador. Ao ver um card assim em `done`, crie os degraus que
faltam encadeados por `parents` — a sua verificação não substitui o papel externo,
porque você roteou o trabalho e é parte interessada.

Quando dois cards fecharam sobre o mesmo risco, um par teste+confirmação cobre os
dois: um card de teste com `parents` nos dois produtores custa menos que duas
cadeias e dá ao confirmador a visão do risco inteiro.

No card de teste, exija medição e não leitura: cenário não executado conta contra
o aceite e o worker deve dizer qual não deu para semear e por quê.

## 6. Pitfalls de escrita de card

- **Aponte a correção na causa, não no sintoma.** Quando um trecho suspeito tem
  justificativa escrita no código, diga no card que ele está certo e onde está o
  erro real — senão o dev "conserta" removendo a coisa certa.
- **Escreva a invariante, não o caso medido.** "nenhum elemento com y<0 para
  qualquer entrada" resiste; "a barra tal aparece" passa com um if.
- **Liste o que é intocável** (paleta com verificação de daltonismo documentada,
  escala de espaçamento já decidida, guarda contra divisão por zero com comentário
  explicando) — o revisor precisa reprovar remoção silenciosa.
- **Ausência de string em bundle minificado não prova nada.** O minificador
  apaga comentários e renomeia símbolos: procurar `Ctrl+Enter` no JS publicado
  para concluir que o atalho não existe é falso-negativo garantido. Verifique no
  fonte, ou no navegador.
- **Worker scratch é apagado ao completar o card.** Cards de review/teste
  encadeados a um pai com workspace `scratch` acham o disco vazio. Aponte o
  card ao caminho real do repo no corpo, sempre.
- **Grep de UM ficheiro não prova ausência; grep do REPO prova.** `grep -c X
  ficheiro.tsx → 0` diz «não está aqui», não «não existe». Antes de declarar
  funcionalidade inexistente, corra `grep -rn <símbolo> src/` e
  `git log --oneline -- <alvo>`: um commit pode tê-la MOVIDO de ficheiro. Concluir
  ausência do zero local faz o card mandar reimplementar o que já está commitado
  — e proteção duplicada é a origem do bug que ela devia evitar.
- **Teste que lê texto-fonte quebra em `git mv`, não em regressão.** Vermelho num
  teste de literal significa «o alvo mudou de sítio» tantas vezes quanto
  «o código partiu». Verifique qual dos dois antes de abrir card.
- **Renomear chave de i18n quebra os testes que afirmam o texto-fonte — e o
  vermelho é do teste.** Testes com `readFileSync` + `toContain("t('chave')")`
  guardam contrato real (módulo visível sem restrição de país, aba fora de uma
  flag) usando literais como refência frágil. Antes de editar o teste, confirme
  no fonte que a renomeação ficou **coerente em todos os pontos** — inclusive o
  `id` da aba e o `activeTab === '...'`, que um `grep` só pela chave de tradução
  não alcança. Atualize os literais, **mantenha as invariantes**, e prove por
  mutação que o teste ainda guarda alguma coisa: reintroduzir a condição que ele
  proíbe tem de matá-lo. Sem essa prova você trocou literal por literal e o teste
  virou espelho. Deixe comentário datado dizendo o porquê da renomeação.
- **Falha de teste por serviço fora do ar não é regressão — prove e diga qual é.**
  `Can't reach database server` num teste de login é ambiente, e confundi-lo com
  defeito manda o produtor caçar bug inexistente. A prova é barata:
  `git status --porcelain` mostra que nenhum arquivo daquele módulo foi tocado.
  Separe sempre «falhas minhas» de «falhas de ambiente» na contagem que você
  repassa, com a mensagem de erro colada.
- **Suíte por diretório esconde o vermelho que está fora dele.** `vitest run
  src/hooks/ src/components/` dá verde enquanto `src/lib/` arde. No portão de
  qualquer card, exija `vitest run` SEM argumento de caminho, e desconfie de
  relatório cujo comando tenha um diretório depois do `run`.
- **Teste pode cobrar código que nunca foi escrito — ou que só mudou de sítio.**
  Que o teste seja novo (`??` no git status) diz que ninguém o rodou ainda, não
  que o alvo não existe. Nunca conclua «nunca foi escrito» a partir do grep ao
  ficheiro que o teste nomeia: corra `grep -rn <símbolo> src/` e
  `git log --follow --oneline -- <alvo>` ANTES. Só zero no repo inteiro é
  funcionalidade por implementar; zero no ficheiro nomeado costuma ser um commit
  que moveu o alvo, e aí o vermelho é do teste, não do produto.
- **Teste reprovado por quebra de assertivas nominais exige alinhamento.**
  Se uma refatoração ou redesign de componentes (ex: troca do separador visual `—` para `:` ou de texto truncado para o texto `i18n` inteiro) for corretamente confirmada visualmente e operacionalmente pelo revisor, mas a `pipeline` reprovar o artefato porque os antigos unitários seguem checando as exatas `strings` brutas depreciadas, avance. Crie um card derivado rápido de `Dev` voltado apenas para o alinhamento de texto e sufixos nos testes, liberando os validadores de checarem o mesmo escopo visual e impedindo o recuo na branch.
- **Teste que reimplementa a lógica não é teste, é espelho.** Copiar a função
  para dentro do ficheiro de teste e verificar a cópia passa verde com o
  componente real completamente partido. Monte o componente real (jsdom/
  Playwright) e prove por mutação NA PRODUÇÃO — remover o handler tem de matar
  testes. Custa mais linhas; é a única forma de o defeito ter onde se prender.
- **Antes de escrever o teste que prova o defeito, leia a config do runner.**
  Projeto com `environment: 'node'` no `vitest.config` exige
  `// @vitest-environment jsdom` na PRIMEIRA linha de cada ficheiro que monta
  componente; sem ela o erro é `document is not defined` e parece defeito do
  teste. E `vi.mock` é içado acima dos `const` do módulo: a fábrica tem de
  construir os dados dentro dela própria e exportar a mesma forma que o
  componente importa (`default` além do nomeado), senão o mock resolve
  `undefined` em runtime. Copie o setup de um teste vizinho que já monta DOM em
  vez de o deduzir.
- **Clique sintético e clique real dão resultados diferentes.** `element.click()`
  ou `dispatchEvent` saltam heurísticas do navegador que o clique de rato
  percorre. Antes de concluir que um defeito de UI existe, meça o quadrante
  inteiro: real×sintético × HEAD×mutado. Só o quadrante real+mutado distingue
  «o código está partido» de «a medição é que estava».
- **Correção previne o futuro; os dados do passado ficam.** Ao fechar um card
  que corrige geração de valor (token, slug, chave), pergunte: e os registos JÁ
  gravados com o defeito? Backfill que filtra `where: { campo: null }` só
  alcança quem nunca teve valor — nunca quem tem valor errado. A dívida precisa
  de card próprio, e a primeira tarefa desse card é MEDIR, não corrigir:
  correção inventada para problema que os dados não têm é risco gratuito.
- **Import presente não é chamada feita.** `runWithCountry` importado, país
  passado como parâmetro, comentário prometendo «contexto por iteração» — e a
  chamada ausente. Grep por `runWithCountry\(` (com parêntese), não pelo nome:
  o bug sobrevive a toda leitura que confere o import.
- **Comentário que promete comportamento é suspeito, não prova.** Onde o
  comentário afirma o que o código faz, leia a linha seguinte: a versão mais
  enganosa de um defeito é a que tem documentação correta em cima.
- **Teste que passa contra o código atual refuta a sua hipótese, não o defeito.**
  Quando o defeito é reprodutível em navegador e o teste que você escreveu para
  reproduzi-lo passa, a conclusão é «a causa é outra» — nunca «não há bug». Prove
  que o teste guarda alguma coisa (mutação que o mate) e então volte a procurar a
  causa; escreva no card que o teste fixa o contrato mas **não cobre o defeito**,
  senão o próximo worker lê verde e arquiva o sintoma vivo.
- **Antes de culpar o handler, confira a ordem das linhas.** Guarda que descarta
  eventos raramente engole o atalho tratado acima dela. Leia o corpo do listener
  na ordem em que executa antes de escrever «a guarda bloqueia» — hipótese de
  causa escrita no card sem essa leitura manda o produtor reescrever código são.
- **Defeitos que passam pelo mesmo ponto do código são um só até prova contrária.**
  Dois sintomas distintos que terminam na mesma chamada (`requestSubmit()`, o
  mesmo reducer, o mesmo efeito) provavelmente têm causa única. Diga isso nos dois
  cards e mande testar o irmão depois de corrigir o primeiro — senão o segundo
  produtor «conserta» um defeito que já não existe.
- **Atribua a quebra ao arquivo que o compilador nomeia, não ao que mudou.**
  `tsc`/`eslint` imprimem o caminho em cada linha de erro. Num repo com vários
  workers, o arquivo novo e o arquivo quebrado raramente são o mesmo — um
  testador gastou o turno inteiro perseguindo o arquivo errado.
- **Instrumento de medição não mora em `__tests__/`.** Arquivo sem nenhuma
  asserção, que existe só para imprimir número com `console.log`, é script.
  No diretório de testes ele é varrido por `tsc`/`eslint` e derruba o portão de
  toda a equipe. Ao limpar, **mova para fora do repo, não apague** — pode ser
  trabalho vivo de outro worker.
- **Triagem de script solto é por conteúdo, não por extensão.** Worker que
  investiga deixa `.mjs` na raiz, e eles não são a mesma coisa: rascunho de 3-8
  linhas (import de pacote não instalado, ficheiro truncado, patcher de uso único
  já aplicado) é lixo; o de centenas de linhas que reproduz a medição é o que
  sustenta a conclusão do card. Abra cada um antes de decidir.
- **Mutador abandonado na raiz é risco de produção mutada.** Script de
  investigação que reescreve um ficheiro de produção pode ter sido interrompido
  antes de restaurar. Antes de mover ou limpar, grepe o alvo pelo marcador do
  mutante e pelo original — confirmar que a versão sã está no disco custa um
  comando e evita publicar código que ninguém escreveu de propósito.
- **Instrumento preservado sem entrada em `package.json` apodrece.** Ficheiro em
  `scripts/` que ninguém sabe invocar vira órfão que alguém apaga por limpeza, e
  a capacidade de medir volta a zero. Ao preservar um, ou dê-lhe um `npm run` e
  uma linha de README, ou tire-o da árvore — ficar meio dentro é o pior dos três.
- **Mutação que não alterou o arquivo é indistinguível de mutação que não mata.**
  Se a âncora do `replace`/regex não casar, a suíte passa e você conclui que o
  teste não guarda nada — quando só testou o arquivo intacto. Sempre
  `assert old in s` antes de escrever, e confira o md5 depois de restaurar.
  Para guarda de uma condição, o mutante mais barato é trocar o predicado por
  `if (false)`: desliga a proteção sem mexer no corpo, e os nomes dos testes que
  morrem dizem qual comportamento a guarda sustenta — cole-os no card, valem mais
  que a contagem de falhas.
- **Mutação de UMA ocorrência não refuta o teste; mute a CLASSE inteira.**
  Reverter o token defeituoso num só lugar (`replace(..., 1)`) atinge uma linha
  que pode não renderizar no cenário testado, e a suíte passa — conclusão falsa
  de que o teste é decorativo. Conte as ocorrências, mute **todas**, e só então
  julgue: um teste de contraste que sobreviveu a 1 mutação morreu nas 24.
  Acusar de inútil um teste válido custa o mesmo que aprovar um teste cego.
- **Restaurar exige a precisão que mutar dispensou.** O predicado que você mutou
  em massa costuma ter usos legítimos no mesmo ficheiro — `saldos.pior.valor < 0`
  era rótulo numa linha e cor de saldo negativo noutras duas. Substituição global
  na volta repõe a correção **e** reescreve código são, sem deixar rastro no
  diff do card. Restaure por número de linha (com `assert` do conteúdo esperado
  naquela linha) e feche exigindo `git diff -- <ficheiro>` **vazio**: idêntico ao
  `HEAD`, byte a byte, é a única prova de que a medição não deixou resíduo.
  Script de restauração que aborta por contagem inesperada está a proteger-te —
  investigue as ocorrências antes de afrouxar o `assert`.
- **Aviso em `stderr` com suíte verde é suíte cega, não suíte limpa.** `act()`
  sem `globalThis.IS_REACT_ACT_ENVIRONMENT = true` faz o React 18 avisar
  «testing environment is not configured to support act(...)» e **não aplicar os
  efeitos**: o componente nunca sai do estado de carregamento, a varredura mede
  o esqueleto e todos os `expect` passam por não terem o que medir. A suíte
  esconde o aviso no `stderr` e reporta verde. Ao herdar teste de outro worker,
  `grep -L IS_REACT_ACT_ENVIRONMENT` nos ficheiros que chamam `act(` antes de
  confiar no verde — e instrumente com `console.log` do tamanho do DOM e da
  contagem de alvos quando a mutação não matar: `alvos=0` prova cegueira,
  `alvos=17` prova que o teste vê e a sua mutação é que errou o alvo.
- **Portão longo vai para background desde o início.** Suíte grande com mutação
  e restauração estoura o teto de primeiro plano do terminal e é promovida a
  processo de fundo no meio do comando; a espera por ele também tem teto menor
  do que se pede. Encadeie mutação + suíte + restauração num comando só, rode em
  background com notificação, e desenhe o comando para restaurar por md5 mesmo
  se a suíte falhar — senão o arquivo fica mutado no repo dos irmãos.
- **`grep` case-sensitive não prova ausência.** Antes de afirmar «N ocorrências»
  num card, repita com `grep -i` e com raiz curta (`debounc`, não `debounce`):
  hook `useDebounced` num repo que nomeia em português não aparece em
  `grep "debounce"`. Card que manda implementar o que já existe queima um run
  inteiro e arrisca sobrescrever código em produção.
- **Servidor de desenvolvimento que você sobe é seu para derrubar — e só o seu.**
  Numa máquina com vários projetos há servidores órfãos de sessões anteriores
  ocupando portas; confirme o dono por `CommandLine` do PID antes de matar
  qualquer um, porque derrubar o de outro projeto parece defeito da app alheia.
  Escolha porta improvável em vez de reciclar a convencional: com `--strictPort`
  o processo morre em silêncio se a porta estiver tomada e você passa a medir o
  servidor de outro projeto respondendo no endereço que julga ser o seu.
- **Hook de segurança recusa comando com valor interpolado em runtime.** PID ou
  caminho capturado por substituição de comando e injetado em invocação de
  PowerShell não passa na avaliação estática e o comando nem chega a correr.
  Reescreva com o valor literal (uma leitura antes, o comando depois) em vez de
  contornar o bloqueio — ele é do usuário, não seu.
- **Comando longo de uma linha estoura a avaliação do hook antes de correr.**
  `python -c` com script embutido, heredoc, ou encadeamento de muitos `;` volta
  como «could not complete safety evaluation» — falha de tempo na checagem, não
  recusa por perigo, e reexecutar igual repete o estouro. Grave o script com
  `write_file` e invoque-o pelo caminho (`python mut.py mutar`): a linha de
  comando fica curta, o script fica legível e reutilizável, e o hook avalia em
  tempo. O mesmo vale para `git commit -m` com corpo de vários parágrafos.
  Encadear com `&&` em vez de `;` também costuma passar onde o `;` estourou.
- **`NODE_ENV=production` exportado no ambiente** faz `npm install` apagar as
  devDependencies do `node_modules` (vitest, tsc, eslint somem no meio do
  trabalho). Escreva nos cards que instalam algo: use
  `NODE_ENV=development npm install --include=dev`.
- Em teste de IDOR, o esperado é **404, não 403**: 403 confirma que o id existe e
  vira oráculo de enumeração.
- **Proíba `git checkout` por caminho, não só `checkout .`** — com vários workers
  no mesmo repo, `git checkout HEAD -- package.json` apaga a mudança de outro
  card junto com o próprio ruído, sem deixar rastro. Escreva no card: instale
  fora do repo, ou aceite o ruído e declare. Vale o mesmo para `reset --hard`,
  `stash` e `clean`.
- **Uma frente por card quando o critério exigir confirmação em navegador.** A
  verificação visual sozinha consome a maior parte do orçamento de runtime; seis
  frentes independentes num card só estouram o relógio e queimam o run inteiro.
  Corte por frente e feche o escopo no corpo ("não amplie se sobrar tempo"), com
  `goal_max_turns` baixo.
- **Nomeie os sósias que o worker vai encontrar.** Se o repo tem ocorrências
  parecidas com o alvo mas de outra função (um `400 ms` que é gravação de
  preferência, não busca), escreva arquivo e linha delas no card — sem isso o
  produtor "reaproveita" a errada e quebra outra coisa.
- **Guarda que lança está certa; o bug é o chamador.** Quando um acesso falha numa
  verificação deliberada, prove pelo outro entrypoint (a mesma função via rota
  autenticada costuma funcionar, porque o middleware já abriu o contexto) e escreva
  no card que o arquivo da guarda é intocável, com critério de reprovação explícito
  — `git diff HEAD -- <guarda>` tem de sair vazio. Sem isso o produtor "conserta"
  com valor default e troca falha alta por escrita silenciosa no lugar errado.
- **Quando N chamadores usam o mesmo helper, o card corrige o helper.** Mande
  `grep` pelos chamadores e liste-os no corpo, mas escreva que a correção é na
  função compartilhada — corrigir chamador por chamador deixa o próximo a nascer
  com o defeito e multiplica a revisão por N.
- **Depois de diagnosticar um caso, procure a classe** (`grep` do padrão nos
  irmãos) e leve o resultado para card separado, encadeado ao primeiro para que a
  convenção seja decidida uma vez só — consertar 1 de 8 deixa 7 armadilhas com
  aparência de resolvido.
- **Proíba executar script destrutivo contra dado real para "testar".** Script que
  apaga registro ou reescreve PII em lote não se verifica rodando: a execução é o
  próprio incidente que o card previne. Verificação é teste automatizado e leitura.
- **Incoerência aparente entre dois módulos costuma ser propósito diferente.** O
  mesmo valor tratado com `Math.abs` num sítio e sem ele noutro não é bug
  automático: quem **desenha** precisa de magnitude, quem **soma** precisa do
  sinal. Leia o comentário e o teste do lado que parece errado antes de abrir card
  — outro worker pode já ter medido e documentado a escolha no próprio arquivo.
- **Achado roteado para card que não existe é achado perdido.** Antes de fechar
  um card citando «roteado para t_xxxx», confirme o id no board; se não existir,
  ou crie o card ou verifique se a dívida já foi paga e registre onde.
- **Não prescreva a correção** ("aplique `Math.abs` aqui"). Descreva o sintoma, o
  arquivo e a pergunta que decide — a prescrição vira teste que carimba o erro
  quando o diagnóstico está errado. Em número financeiro, pergunte sempre se o
  valor é fato apurado ou artefato: esconder sinal real com módulo viola L006 e
  troca o resultado do mês de sinal.
- **Card de copy nomeia o ficheiro de traduções e proíbe `pages/`.** «Escreva
  copy explicativa para 5 páginas» devolve refatoração de markup: o agente troca
  classes utilitárias por classes próprias, produz centenas de linhas de diff,
  compila limpo — e não escreve uma frase. Declare o entregável como **valor de
  string no dicionário** e liste as chaves a corrigir com o texto atual colado.
- **A contagem de chaves de i18n audita entrega de copy em um comando.** O gate
  de paridade imprime o total (`382 chaves × 4 dicionários`); se o número e os
  valores citados no card estão idênticos ao de antes, nenhuma copy entrou, por
  maior que seja o diff. Confirme também que as chaves nomeadas no corpo mudaram
  de valor — chave nova de rótulo (`common.soon`, `service.benefits`) infla o
  total sem explicar nada.
- **Exija `[A CONFIRMAR]` como entregável listado, não como rodapé.** Card que
  proíbe inventar preço, prazo ou SLA e volta com zero marcações não encontrou
  todos os dados — omitiu a lacuna. A lista de lacunas é o que sobe para o dono
  decidir; sem ela a copy fica muda justamente onde ele precisava responder.
- **Lacuna declarada como "nenhuma" é auto-absolvição — verifique você mesmo.**
  Um card de pesquisa em tema regulado fechou em 4 min com a secção final a
  dizer «nenhum ponto ficou sem verificação primária; todos os dados vigentes».
  Duas consultas derrubaram: o artigo citado para prazo de pagamento (14.133
  art. 141) trata de **ordem cronológica** e não fixa prazo nenhum, e um projeto
  de lei em tramitação estava escrito no meio do parágrafo de regra vigente. O
  sinal é a combinação **tempo curto + zero lacuna**; a citação que costuma
  estar errada é a do artigo mais central, porque é a que o modelo "sabe" de cor
  e não vai conferir. Antes de deixar subir, abra 2-3 citações âncora na fonte
  oficial e confirme que o dispositivo diz o que o documento afirma.
- **Ao injectar os seus achados no card do auditor, diga também o que está
  CERTO.** Lista só de erros faz o auditor reprovar em bloco e o produtor
  reescrever as partes boas. E separe o que **você** verificou do que falta
  verificar — o auditor precisa de saber onde começa o trabalho dele.
- **Documento que se contradiz entre duas secções é achado próprio.** O mesmo
  dossiê afirmou «o pregão achata a margem» numa secção e «margem excelente por
  ausência de competição» noutra. Nenhuma das duas frases isolada parece errada;
  só a leitura de ponta a ponta apanha. Exija do auditor que reconcilie, em vez
  de corrigir uma das duas ao acaso.
- **Correção de achado de pesquisa costuma FORTALECER a tese — diga isso no
  card.** O dossiê fundamentava o risco de capital de giro num prazo legal de
  30-60 dias que não existe; a verdade (não há prazo legal uniforme para
  município, e o marco é a liquidação, não a entrega) é **pior** para o
  fornecedor, logo a tese fica mais dura. Sem essa frase no card, o produtor lê
  «citação errada» como «conclusão errada» e amputa o capítulo certo.
- **Ao reprovar um produtor, cole a lista do que NÃO tocar.** O card de correção
  que só lista erros convida a reescrita integral e perde as partes verificadas.
  Nomeie os dispositivos confirmados um a um — custa três linhas e poupa um run.
- **Ao criar o card de correção, religue o testador no MESMO turno.** O testador
  tinha `parents` nos auditores; o card novo nasce fora dessa cadeia e o testador
  dispararia sobre a versão por corrigir. `kanban_link(parent=<correcao>,
  child=<testador>)` imediatamente a seguir ao `kanban_create` — e confirme a
  lista de pais depois, que é a única leitura que mostra a cadeia como o
  dispatcher a vê.
- **Contradição entre título e conteúdo da página é achado de copy, e o agente
  não decide o fato.** «Escolha sua Escala» sobre um card único promete o que a
  página não entrega. Mande ler o componente para contar o que realmente
  renderiza e ajustar o título à realidade, com proibição explícita de inventar
  a opção que falta — quantos planos existem é decisão do dono, e a resposta
  sobe como pergunta.
- **Trabalho visual de UI/UX exige alteração na base, não só wrappers isolados.** Quando o reclamante apontar que "nada mudou" apesar de novos cards e skills visuais executados, o dev anterior gerou código invisível (layers de transição sem efeito, novos arquivos intocados). Aceite a frustração do usuário, assuma o comando analítico por meio da inspeção de untracked files e `git diff`, e lance uma nova sub-rede focada em EXIGIR que as bibliotecas e design systems injetados toquem efetivamente a casca estética e substitua as marcações secas. Reprove edições tímidas.
- **O router do usuário proíbe estritamente usar/acionar a linha Fable.** Não delegue tarefas, nem atribua perfis a painel/orquestra pedindo explicitamente pelo modelo "Fable" no OmniRoute, independente da natureza do texto a gerar. É um bloqueio rígido do operador perante a API.
- **Visual: Herança de padding não substitui `gap` ativo.** Corrigir espaçamento desigual de itens "flex" em Navbar não se faz adivinhando herança de CSS vindo de terceiros (`community.css`): force a `gap` no elemento-pai container e zere a assimetria setando os `paddings` laterais com igualdade absoluta em todos os componentes-filhos, impedindo diferenças nos hitboxes ou hover effects.
