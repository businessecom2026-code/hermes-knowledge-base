---
name: auditoria-verificada
description: Verificar achados de auditoria antes de entregá-los.
metadata:
  version: 1.0.0
---

# Auditoria verificada

Use ao auditar site, app ou codebase, e ao consolidar achados de auditores delegados em um relatório.
Dispara em "auditar", "auditoria", "revisar o site", "diagnóstico", "análise técnica",
"levantar problemas", "consolidar achados", "veja se o que o outro agente fez faz sentido",
e sempre que um subagente devolver lista de achados para repassar ao usuário ou outro agente
commitar no mesmo repositório e o usuário pedir sua leitura.

Auditar é fácil; **entregar achado que se sustenta** é o trabalho. Esta skill cobre o ciclo inteiro:
medir, delegar, verificar, consolidar e corrigir o que você mesmo publicou errado.

## Regra número um

**Nenhum achado chega ao usuário sem verificação.** Nem o de subagente, nem o seu.
Um relatório com 24 itens dos quais 11 são falsos é pior que um relatório com 13 itens —
o usuário perde a confiança no conjunto todo e precisa reauditar sua auditoria.

Ao consolidar, separe explicitamente: **confirmado** / **falso, descartado** / **medido**.
Declarar o que você descartou e por quê é o que dá peso ao que você manteve.

## Procedimento

### 1. Meça antes de ler código

Rode a coisa e observe. Medição resolve em minutos disputas que leitura de código não resolve,
e cria a base factual contra a qual todo achado posterior é julgado.

O que medir sempre: erros de console, requisições que falham, FPS/frame time, heap ao longo de
ciclos de navegação, o que de fato é clicável e focável, e o HTML servido antes de hidratar.

Receita de execução em `references/medicao-em-navegador.md` — inclui subir e derrubar o preview do
build, e a receita de captura de tela com leitura de imagem para o que é julgamento visual.
Quando a auditoria tocar dado pessoal, determine a jurisdição **antes** de citar lei:
`references/jurisdicao-dados-pessoais.md`.

**"Quero ver como ficou" se responde com a tela, não com tabela.** Prova de comportamento
(`typeof`, cookie, contagem de nós) e prova de aparência são evidências diferentes; quem pede para
ver o front já aceitou a primeira e está pedindo a segunda. Capture cada estado que importa, leia
as imagens com pergunta fechada e descreva o que aparece — repetir a tabela de medição nesse ponto
lê como evasão.

### 2. Delegue por domínio, com escopo somente-leitura

**Antes de delegar ou editar, verifique se o checkout está sozinho.** Outro agente escrevendo nos
mesmos arquivos sobrescreve em silêncio — a segunda escrita ganha, sem conflito nem erro. Arquivo
com mtime de minutos atrás é trabalho vivo, não achado seu. Com mais de um agente no mesmo
checkout sem worktree separado, fique na metade somente-leitura e diga ao usuário por que não
editou. Receita em `references/retomar-auditoria-interrompida.md`.

**Quando quem despacha vários executores é você, a colisão é sua para prevenir.** Dois ou três
cards rodando ao mesmo tempo no mesmo checkout, sem worktree por tarefa, são agentes escrevendo
nos mesmos arquivos sem conflito nem aviso. Antes do primeiro pegar o trabalho, escreva em cada
tarefa: a fronteira de escopo (que arquivo e que assunto é de quem), proibição explícita de
`git reset --hard`/`stash`/`clean`/`checkout .` — que apagam o trabalho não-commitado dos outros —
e preferência por edição cirúrgica em vez de reescrita de arquivo inteiro nos arquivos grandes e
compartilhados. Fronteira combinada depois que todos já começaram não desfaz sobrescrita.

Um auditor por domínio (código, performance, copy, SEO/conformidade, motion), cada um com
"NÃO altere arquivos" no enunciado. Peça saída estruturada com `arquivo:linha` em cada achado —
achado sem âncora é achado que você não consegue verificar.

**Passe para o auditor o contrato que você já leu.** Quando você leu o backend e vai delegar o
front (ou o inverso), inclua no enunciado a lista concreta de códigos de erro, status HTTP,
campos obrigatórios e regras de validação que o outro lado emite. Sem isso o auditor gasta o
contexto redescobrindo o que você já sabe e devolve achados genéricos de estilo; com isso ele
audita a **divergência de contrato**, que é a classe de achado mais valiosa: código que o servidor
emite e a tela nunca traduz, validação que o front não espelha, campo que o servidor exige e o
formulário não pede. Nomeie no enunciado a hipótese que você quer confirmada ou refutada —
auditor com pergunta fechada devolve resposta verificável; auditor com escopo aberto devolve lista.

**Recorte a delegação por módulo, não por arquivo.** Um auditor por módulo funcional, com os
arquivos de front e o contrato de backend daquele módulo juntos. Dividir por camada faz cada
auditor ver metade do contrato e nenhum dos dois consegue apontar a divergência.

### 3. Verifique cada achado antes de repassar

Este é o passo que não pode ser pulado. Ver a seção de armadilhas abaixo.

### 4. Corrija seus próprios achados em lugar

Quando a verificação contradiz algo que você já entregou, **edite a afirmação onde ela está**
e marque a correção, com a causa real ao lado. Não deixe a versão errada em pé em um arquivo e
a certa em outro.

### 5. Feche com o que está bom

Toda auditoria séria lista o que foi verificado e **aprova**. Sem isso o time reescreve código
que já estava certo, e o relatório lê como ataque em vez de diagnóstico.

### 6. Verifique a proposta contra o código antes de virar tarefa

Achado verificado não é tarefa verificada. Entre "o concorrente faz X" e "vamos fazer X" há um
passo que se pula com facilidade: **procurar X no código do usuário**. Para cada melhoria que
você vai propor, rode `grep` pelo comportamento no destino — a frase do estado vazio, o valor
padrão do formulário, o componente de confirmação — e proponha só o que não achar. A busca é de
minutos; costuma derrubar metade da lista.

Despachar agente para implementar o que já existe custa duas vezes: gasta execução e gera
conflito de escrita num arquivo que já estava certo. Quando o usuário pede revisão antes de
executar, é este passo que ele está pedindo — e a resposta certa a "pode executar" pode ser
"executei a verificação e não há o que fazer".

Vale também para benchmark: o que se copia de um concorrente é o **mecanismo medido** (como o
modal sobrevive, quantas decisões o formulário toma sozinho), não a aparência. Confirme que o
mecanismo não está implementado antes de propor o trabalho.

## Auditoria que depende de um gesto humano

Login, 2FA, captcha, credencial de produção e aprovação em dispositivo são do usuário, sempre.
Nunca adivinhe credencial nem tente contornar o gesto.

O erro caro aqui não é pedir — é **parar**. Auditoria tem sempre uma metade somente-leitura que
não depende do gesto: código, contrato de API, HTML servido, testes. Quando bater o bloqueio:

1. **Meça se o bloqueio ainda é real** antes de repetir o pedido. Estado externo muda sozinho
   entre uma checagem e outra, e pedir de novo algo que o usuário já fez queima confiança.
   Verifique o estado de fato (sessão presente? cookie? processo no ar?), não a sua lembrança dele.
2. **Confirme que a superfície do gesto é visível para o humano antes de pedir o gesto.** Navegador
   headless não tem janela: você lê a página por protocolo e descreve uma tela que no monitor dele
   não existe. Pedir "faça login na aba que abri" contra uma janela invisível gasta o tempo dele
   procurando nada e depois exige que você admita o erro. Cheque o `userAgent` (contém `Headless`?)
   ou liste as janelas com título do sistema operacional — receita em
   `references/medicao-em-navegador.md`.
3. **Diga o que falta em uma linha**, com o alvo exato (qual janela, qual aba, qual perfil) e o
   que acontece depois que ele fizer. Pedido longo não é lido.
4. **Dispare a metade somente-leitura em paralelo** enquanto espera, e encerre o turno dizendo o
   que está rodando. Esperar ocioso gasta o tempo do usuário sem produzir nada.
5. **Declare no relatório o que ficou sem cobertura** se o gesto nunca vier — achado de leitura e
   achado de execução têm pesos diferentes, e misturá-los sem dizer qual é qual infla a auditoria.

Auditoria longa é interrompida com frequência. Para retomar sem reauditar o já feito:
`references/retomar-auditoria-interrompida.md`.

## Quando o pedido é refinar sem reorganizar

"A estrutura se mantém, só melhoramos" é restrição de escopo, não convite a mover arquivos. O
trabalho que cabe aí quase nunca é rearranjo: é **fechar buraco na rede de proteção** — fronteira
sem tipo, arquivo fora do conjunto verificado, invariante que só existe na cabeça de quem
escreveu. Procure erro que passaria por build, type-check e suíte sem produzir mensagem nenhuma;
é o achado de maior valor com o menor diff.

Prefira sempre o aditivo: declaração de tipo ao lado da fonte, script de verificação novo, entrada
em `package.json`. Não edite arquivo declarado como acervo registrado, mesmo para consertá-lo.

E registre o que **não** fez, em tabela, com a medida ao lado (tamanho do arquivo, fan-in,
quantidade de estado) e uma frase de por que ainda não dói. Assim a decisão de reorganizar fica
disponível com dado, o usuário vê que você mediu em vez de ignorar, e ninguém confunde "fora do
escopo de hoje" com "não existe".

Receita completa — grafo de imports, paridade de i18n, checagem da fronteira de tipos e a forma dos
gates: `references/auditoria-de-estrutura-e-gates.md`.

## Armadilhas que custam caro

1. **Afirmação de ausência vinda de leitura de código é não-confiável.** Um agente que lê sem
   executar converte "não encontrei X" em "X não existe". Rode `grep` para cada `dispose()`,
   `matchMedia`, loader, listener ou guarda que o auditor declarou faltando — a taxa de erro
   nessa categoria específica é alta o bastante para justificar a verificação item a item.

2. **Medição de runtime adjudica alegação de vazamento.** Heap estável ao longo de vários ciclos
   de montagem/desmontagem derruba qualquer alegação de recurso não liberado, sem precisar auditar
   o caminho de cleanup linha a linha.

3. **Confira se o auditor leu `dist/` em vez do fonte.** Conclusão sobre "código morto" ou
   "não está no bundle" tirada de build antiga descreve um app que não existe mais. Compare o
   mtime do artefato com o do fonte antes de aceitar.

4. **Bytes não são linhas.** Achado do tipo "esse arquivo é um stub de 350 bytes" costuma ser
   `wc -c` lido como `wc -l`. Cheque o tamanho real antes de repassar.

5. **Severidade depende do caminho crítico, não da existência.** Peso que não é importado pela
   rota auditada é dívida técnica, não problema de carregamento daquela rota. Confirme quem
   importa o quê antes de aceitar a severidade que o auditor atribuiu.

6. **Um achado pode estar certo no sintoma e errado na causa** — e então a correção proposta
   também está errada. "Não existe consulta de preferência" vs. "a consulta existe mas roda depois
   do recurso já ter sido criado" medem igual e se corrigem de formas opostas. Localize a causa
   antes de escrever a tarefa.

7. **O DOM da página não é o roteamento do app.** Ausência de link ou elemento em uma página não
   significa que o recurso não exista no projeto: procure a rota e o componente antes de concluir
   que algo "não existe". A causa costuma ser "existe mas não é renderizado aqui" — correção
   muito mais barata que a que você escreveria sem checar.

8. **Quando a delegação não volta, faça você mesmo.** Se um auditor falhar repetidamente, execute
   aquele escopo diretamente em vez de deixar lacuna silenciosa. E **declare no relatório o que
   ficou sem cobertura** — lacuna não anunciada vira decisão tomada com base incompleta.

9. **Evidência de design tirada do site de marketing não descreve o produto logado.** Tokens
   extraídos do CSS da landing (cor, raio, duração, easing) valem para a landing; o app atrás do
   login costuma ter outro tema, outra densidade e outra escala. Declare a origem da evidência
   junto do achado e confirme dentro do produto antes de recomendar mudança nele — recomendação
   baseada na vitrine faz o time mexer no que não foi medido.

10. **Decisão registrada no código é decisão tomada.** Comentário datado, mensagem de commit e
   `git log` do módulo carregam escolhas de produto já feitas — e às vezes já revertidas mais de
   uma vez. Antes de propor mudança estrutural (navegação, agrupamento, hierarquia de menu),
   `grep` os comentários da área e leia o log: propor o que o dono recusou há poucos dias queima
   a proposta inteira, inclusive a parte boa dela.

11. **Comparação antes/depois com o "antes" vazio aprova qualquer coisa.** Um teste que lê
   `{modais: 0, inputs: 0}` antes e depois e conclui "sobreviveu" não testou nada. Afirme que o
   estado inicial é não-vazio antes de comparar — se o cenário não montou, o resultado é "falhou
   em montar", que é diferente de "passou". Vale para todo instrumento: quando a medição devolve
   ausência uniforme, suspeite do instrumento antes de concluir sobre o alvo.

   Em auditoria de interface a mesma falha vira **achado invertido**: tabela sem registro não
   renderiza caixa de seleção, barra de ação em lote, paginação nem estado de carregamento, e você
   reporta como inexistente o que existe e funciona. Semeie dados antes de medir tela, e antes de
   despachar alguém para implementar um recurso "faltante", `grep` o nome dele no fonte — inclusive
   nas rotas do backend. Mandar reimplementar o que já está pronto gasta execução e cria conflito
   de escrita num arquivo que estava certo.

12. **Número lido na tela não é número lido no código.** Ao afirmar quantidade sobre um codebase
   — itens de menu, ocorrências, linhas —, a fonte tem de ser `grep`/`wc` no fonte, com o caminho
   conferido. Contagem tirada da interface ou da memória e apresentada como fato do código é a
   classe de erro mais fácil de o usuário desmentir, e derruba junto o que estava certo.

13. **A correção que você propõe é, ela também, um achado não verificado.** Um relatório costuma
   ser rigoroso no sintoma e crédulo na solução: "comprimir o asset dá −75%, 3h, sem tocar em
   código" tem a mesma forma de um achado medido e nenhuma medição por trás. Antes de a proposta
   entrar no plano com estimativa de esforço, **execute uma vez** — rode a ferramenta, meça o
   ganho real, rode a suíte existente com o resultado no lugar. O padrão de falha é assimétrico:
   o sintoma você observou, a correção você imaginou. Quando a execução contradiz a proposta,
   corrija o relatório onde a proposta está (passo 4) e registre o ganho medido ao lado do
   prometido — "cancelado, ver abaixo" com o número vale mais que remover a linha em silêncio.

14. **Frase de esforço com "sem tocar em código" é sinal de que ninguém leu o consumidor.**
   Toda otimização de artefato — asset, bundle, schema, formato de arquivo — muda uma interface
   que alguém consome. Antes de estimar, `grep` quem lê o artefato e como: identificação por
   nome, contagem de elementos, hash travado em teste. É onde mora a diferença entre 45 minutos
   e uma regressão silenciosa.

15. **Comentário de código não é prova de que a correção chegou à tela.** Um handler que documenta
   em detalhe o defeito que corrigiu diz apenas que o servidor mudou. Se a resposta enriquecida
   depende do front consumi-la — um campo novo no corpo do erro, um caminho de campo, um contador —
   abra o consumidor e confirme que ele lê aquilo. Meia correção deixa o sintoma original de pé e
   o comentário faz o próximo leitor acreditar que está resolvido.

16. **"Você mexeu em X?" se responde com `git`, não de memória.** Rode `git log --stat` desde o
   último commit que não é seu e classifique cada um pelo efeito observável que o usuário
   perguntou (muda a tela? muda a API? toca dado pessoal?). Afirmar escopo de lembrança erra por
   omissão justamente quando a resposta importa — e a dúvida dele costuma ser o momento certo de
   **medir o que você tinha adiado**: a pergunta nomeia a área de risco percebida. Quando a
   medição promove um item de "pendente para depois" a "já funciona", diga isso e **retire o item
   do plano** em vez de deixar a estimativa antiga de pé.

17. **Suíte verde não prova que a correção acerta o alvo, e rodapé de commit não é medição sua.**
   Ao revisar trabalho de outro agente, o "N testes passando" da mensagem descreve a máquina dele
   antes do merge; rode a suíte, o type-check e o build você mesmo, e leia as assertions do teste
   novo perguntando se falhariam caso o comportamento estivesse errado — assertion que só faz
   `grep` de um símbolo no fonte passa com o defeito de pé. Receita completa, incluindo a
   verificação de guarda/trava que não é liberada em todos os caminhos de saída:
   `references/revisar-trabalho-de-outro-agente.md`.

18. **Nunca anuncie commit perdido sem testar ancestralidade.** `reflog` cheio de `rebase (pick)`
   e um topo de `git log` diferente do que você lembrava são a assinatura de um `pull --rebase`
   comum, não de reescrita destrutiva. `git merge-base --is-ancestor <commit> HEAD` decide em um
   comando; alarme falso de trabalho perdido queima confiança na mesma moeda que achado falso.

19. **Órfão não é lixo até você checar o que o projeto declara e o que o bundle carrega.** Antes de
   recomendar apagar arquivo inalcançável, faça duas checagens: `grep` os docs do projeto por
   declaração de acervo ("fonte registrada", "conferida byte a byte", hash travado) e procure no
   build uma string exclusiva do arquivo. Árvore mantida de propósito como referência não é
   código morto, e o que o empacotador remove por tree-shaking não custa byte nenhum ao usuário —
   é comum um só `import` de constante trazer a constante e deixar o resto fora. Auditor que só
   conta alcançabilidade recomenda apagar acervo, que é a versão deste erro com dano permanente.

20. **Instrumento de grafo de imports que não resolve `import()` dinâmico reporta toda página
   preguiçosa como morta.** Rotas carregadas com `lazy(() => import(...))` são justamente as telas
   grandes; se elas aparecem como órfãs, o defeito é seu. E um regex único com `[\s\S]*?` na
   alternativa de `from` atravessa o arquivo inteiro e engole os `import()` seguintes — use
   padrões separados e ancorados por linha (`^\s*import`), e confira a contagem de alcançáveis
   contra o que você sabe que o app carrega antes de publicar qualquer número.

21. **Checagem verde não prova checagem ligada.** Type-check com saída 0 diz que o verificador
   passou nos arquivos que ele olhou, e o conjunto raramente é o que você supõe: `include` de
   tsconfig é allowlist, não descoberta, então arquivo verificado só por ser importado sai da
   rede no dia em que ninguém o importa. Pior, `allowJs: false` com `noImplicitAny: false` faz o
   compilador **resolver** um módulo `.js/.jsx` e tipá-lo `any` em silêncio: props que cruzam essa
   fronteira não são conferidas, e o erro que deveria aparecer fica calado. Liste o conjunto real
   (`tsc --noEmit --listFiles`) e prove a fronteira com um arquivo de sonda sob flags estritas
   antes de afirmar que algo está verificado.

22. **Gate que nunca falha não protege nada — plante uma violação e veja falhar.** Relatório que
   imprime e sai 0 é decoração; e tipo novo que o uso real aceita ainda pode não rejeitar nada.
   Todo verificador que você deixa no repositório se valida nas duas direções: crie o caso ruim
   (arquivo morto proposital, chave de tradução faltando, prop com tipo errado), confirme saída
   diferente de zero com a causa nomeada, remova o caso e confirme que volta a passar. Sem esse
   par, você entregou falso conforto — que é pior que nenhuma checagem, porque desencoraja a
   próxima.

23. **"Já subiu?" se responde com `git` e com a origem aberta, nunca com a tela que estava na
   frente.** Trabalho de agente atravessa quatro estados — no disco sem commit, commitado, enviado
   ao remoto, publicado — e o usuário costuma perguntar por um deles olhando outro. Prove com
   `git log origin/main..main` e comparando `git rev-parse HEAD` com `git rev-parse origin/main`;
   resultado vazio e hashes iguais significam que **nada do que você fez está publicado**, por mais
   linhas modificadas que `git status` mostre. Diga isso em números antes de discutir a aparência.

    **Suíte verde na árvore de trabalho não diz nada sobre o commit.** O verificador lê o disco;
    o repositório guarda o índice. Quando outro agente escreve no mesmo checkout entre o seu
    `patch` e o seu `git add`, o que é staged pode voltar a ser idêntico ao `HEAD` — o git não vê
    alteração, não reclama, e o commit sai com o teste e **sem** a correção que ele testa. Você
    então lê 182/182 verdes produzidos por um ficheiro que o repositório não tem. Antes de fechar
    qualquer commit, prove o conteúdo dentro do índice, nunca no disco:

    ```bash
    git show :<caminho/do/ficheiro> | grep -n '<marcador da correção>'
    git diff --cached --stat          # o ficheiro do produto tem de aparecer, não só o teste
    ```

    Commit que leva o teste sem a correção é a forma mais cara deste erro: fica verde no seu
    terminal, vermelho para quem clonar, e o revisor reprova com razão por não haver diff que
    sustente a mensagem.

25. **Confirme QUAL origem está aberta antes de aceitar "está igual" ou "ficou melhor".** Máquina
   de desenvolvimento acumula servidor: dev server de outro projeto, preview de build velho, e
   andaime de teste que um agente subiu para medir componente isolado. Todos respondem 200 e
   parecem o app. Leia `document.title` e a URL, e cheque de quem é a porta antes de concluir
   qualquer coisa sobre o produto — julgamento de interface feito no servidor errado produz
   "não mudou nada" sobre código que mudou 400 linhas, e faz você redirecionar trabalho que estava
   certo. Quando o usuário for julgar aparência, **suba você a origem certa e diga a URL exata**
   em vez de deixá-lo escolher entre as abas abertas.

26. **Serviço vivo se prova com o status do próprio serviço, não por nome de processo.** Casar
   `python`/`node` numa lista de processos acusa vizinho — a própria TUI, o kernel de execução,
   outro projeto — e você anuncia orquestrador no ar com a fila inteira parada. Rode o `status` ou
   o health check que o serviço oferece e cite a saída dele. Depois de subir, confirme pelo log que
   o trabalho começou a andar (tarefa despachada, tick registrado): processo no ar não é fila
   andando.

27. **Teste vermelho não é regressão até você comparar comportamento com asserção.**
   Suíte que quebra depois de trabalho legítimo costuma acusar a asserção, não o
   código: `toContain` de `className` inteiro cai quando alguém acrescenta uma
   classe correta ou quebra a linha, sem nada ter regredido. Antes de mandar
   consertar o produto, leia o diff da região e decida entre três casos — defeito
   real (corrija o produto), asserção frágil presa a formatação (afira a intenção),
   ou guard que ficou obsoleto porque o trabalho novo implementou o que ele proibia
   (reescreva para guardar a **razão** original, nunca apague). Relaxar a asserção
   até passar sempre — alternância frouxa, `[\s\S]*?` atravessando o arquivo — é o
   mesmo que apagar, com aparência de cobertura. Em qualquer dos três, prove por
   mutação: desfaça a correção no fonte, veja falhar, restaure, veja passar;
   substituindo **todas** as ocorrências do marcador, porque trocar só a primeira
   deixa o guard vivo e te faz concluir que a asserção é decorativa.

28. **Instrumento que devolve defeito também mente — valide nas duas direções antes de contar.**
   A armadilha 11 cobre a medição que devolve ausência uniforme; a falha simétrica é mais cara,
   porque um número grande de defeitos parece trabalho encontrado e ninguém desconfia. Antes de
   publicar qualquer contagem produzida por sonda sua, rode-a contra um **caso que você sabe que
   passa** e um **caso que você sabe que falha**; se o conhecido-bom reprovar, o defeito é do
   instrumento. Acusar defeito onde não há custa mais que omitir: manda o time corrigir código
   correto e derruba junto os achados verdadeiros do mesmo relatório. Quando a verificação
   derrubar um achado seu, **retire-o em voz alta** com a causa — relatório que encolhe de quatro
   para dois itens e diz por quê vale mais que um de quatro.

   As duas sondas que erram com mais frequência em auditoria de interface — nome acessível e
   contraste — têm receita conferida em `references/acessibilidade-e-contraste.md`.

## Formato do achado

```
[SEVERIDADE] #ID — título em uma linha
Sintoma medido: o número, o comando, o que se observou
Causa: arquivo:linha
Por que importa: consequência concreta para o negócio ou para o usuário
Correção: ação específica + esforço estimado
```

Severidade: **CRÍTICO** (quebra função, conformidade ou conversão) · **ALTO** (degrada seriamente) ·
**MÉDIO** (custo real, sem quebra) · **BAIXO** (acabamento).

## Fechamento do relatório

Ordene as ações por **retorno ÷ esforço**, não por severidade. Abra com a linha de itens que somam
poucas horas e entregam o máximo — é ela que faz o time começar. Declare dependências: item que só
surte efeito depois de outro deve dizer isso.

## Relacionadas

`compliance/lgpd-audit` para conformidade de dados · `security/appsec-audit` para segurança ·
`seo/seo-audit` e `seo/aeo-geo` para busca · `dev/diagnosing-bugs` quando o achado vira investigação.
