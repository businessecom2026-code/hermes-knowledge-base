# Fechar e publicar o trabalho de cards concorrentes

Fase terminal da cadeia: vários workers escreveram no mesmo repo e agora é preciso
tirar aquilo do disco e pôr no ar. O problema central é que **os workers continuam
escrevendo enquanto você valida** — validar e commitar em passos separados publica
um estado que nunca existiu inteiro.

## 1. Confirmar o alvo antes de publicar

"Finalizar", "deixar pronto", "subir para eu testar" **não dizem qual ambiente**.
Localhost e produção têm orçamentos de risco opostos, e publicar é caro de desfazer.
Quando a frase admitir as duas leituras, pergunte em uma linha antes de empurrar —
e principalmente antes de publicar código que ainda não passou pelas auditorias
obrigatórias (segurança, LGPD). Ler "pronto" como "em produção" por conta própria
transforma uma dívida planejada em dívida já exposta ao cliente.

Se publicar mesmo assim for a decisão, **declare no fechamento quais gates não
rodaram**, para que a dívida fique assumida em vez de parecer cumprida.

## 2. Congelar um snapshot em vez de commitar o disco vivo

`git add` seguido de validação é uma corrida: entre uma coisa e outra os workers
reescrevem arquivo. Congele o índice em um commit fora de qualquer branch e valide
**esse** objeto:

```bash
git add -u
git add <arquivos novos que o produto precisa>
TREE=$(git write-tree)
SNAP=$(git commit-tree $TREE -p HEAD -m "snapshot de verificacao")
git worktree add --detach "$LOCALAPPDATA/Temp/verify" $SNAP
```

O worktree isolado não recebe as escritas dos workers. Instalar dependências de
novo é desnecessário — aponte para as já existentes:

```bash
cd "$LOCALAPPDATA/Temp/verify"
ln -s <repo>/node_modules node_modules
ln -s <repo>/apps/web/node_modules apps/web/node_modules
```

Rode type-check, lint, suíte e **build de produção** dentro do worktree. Antes de
commitar de verdade, prove que o índice ainda é o mesmo objeto validado:

```bash
git write-tree   # tem de imprimir exatamente o $TREE que você verificou
```

Tree diferente significa que um worker escreveu no meio — revalide, não commite.
No fim, `git worktree remove --force <path>` e `git worktree prune`.

## 3. Deixar a ferramenta de agente fora do commit

`.agents/`, `.claude/`, harnesses de medição e lockfiles de skill são instrumento,
não produto. Monte o commit nomeando arquivos, não com `git add -A`.

O inverso também morde: **arquivo novo que o produto importa tem de entrar**.
Antes de commitar, grepe quem importa cada arquivo não rastreado — um hook novo
usado por quatro componentes fica de fora do `git add -u` e quebra o build de
produção, que é onde ninguém está olhando.

## 4. Publicado não é servindo o código novo

Deploy com status SUCCESS prova que o build terminou, não que o usuário recebe o
código. Confirme no artefato que o servidor entrega:

```bash
curl -s https://<host>/ | grep -oE 'assets/[A-Za-z0-9_.-]+\.js'   # bundle de entrada
curl -s https://<host>/assets/<entry>.js -o main.js
grep -oE '"\./[A-Za-z0-9_-]+-[A-Za-z0-9_-]+\.js"' main.js         # chunks lazy
curl -s https://<host>/assets/<chunk>.js -o chunk.js
```

O hash do bundle mudando entre antes e depois já é sinal; o que fecha é achar os
marcadores do trabalho novo dentro do chunk baixado.

### HTTP 200 num asset pode ser o `index.html` disfarçado

Servidor de SPA responde **200 com a página inicial** a qualquer caminho que não
exista, inclusive `.js`. Pedir um chunk que não está lá devolve 200, o `curl`
salva o ficheiro, e todo `grep` por marcador dá zero — lido como «a correção não
subiu», quando o que falhou foi o pedido. Pior no sentido inverso: status 200
sozinho lido como prova faz declarar verificado um HTML de 18 KB.

Duas defesas, ambas baratas:

- **Meça o tamanho e os primeiros bytes**, nunca só o código de estado.
  `-w '%{size_download}'` e `head -c 60`: JS de produção começa em `var`/`import`
  e pesa centenas de KB; `<!doctype html>` no início de um `.js` é o fallback.
- **Nunca derive o nome do chunk do build local.** O mesmo fonte compilado duas
  vezes, ou compilado no servidor, gera hash diferente — o nome local não existe
  em produção. Extraia os nomes reais do bundle de entrada que o site serve e
  baixe **esses**:

```bash
ENTRY=$(curl -s https://<host>/ | grep -oE 'assets/index-[A-Za-z0-9_-]+\.js' | head -1)
curl -s "https://<host>/$ENTRY" -o entry.js
grep -oE '<NomeDoChunk>-[A-Za-z0-9_-]+\.js' entry.js | sort -u   # hash de produção
```

Comparar md5 do local com o servido também engana: o servido pode vir
comprimido, e md5 diferente com o mesmo nome não prova conteúdo diferente. A
prova é o marcador dentro do chunk certo.

### Ler bundle minificado sem tirar conclusão errada

- **Nome de variável some.** Um estado `moradaAberta` dá zero ocorrências mesmo
  presente — minificador renomeia identificador local. Procure o que sobrevive:
  atributo (`data-seccao`), nome de API do DOM (`requestSubmit`, `onInvalidCapture`),
  classe utilitária, string literal.
- **Valor arbitrário de Tailwind mantém colchete.** `grep 'shadow-'` não casa
  `shadow-[0_8px...]`; escape (`grep -o 'shadow-\['`) ou busque a assinatura
  interna (`rgba(15,23,42,0.06)`). Concluir "as sombras não chegaram" por causa do
  padrão errado inverte um achado verdadeiro em falso alarme.
- **Rota lazy não aparece no HTML inicial.** O chunk da tela só é referenciado
  dentro do bundle de entrada — siga a cadeia em vez de procurar no `index.html`.
- Marcador ausente é **hipótese**, não achado: pode ser só a string de
  documentação que não existe. Diga que está por provar em vez de afirmar falha.

## 5. Teste que quebra sem o comportamento mudar

Card de UI quebra suíte por **asserção de string exata** com muita frequência:
adicionaram `z-10` a uma coluna presa, quebraram o `className` em duas linhas, e o
`toContain` de um literal inteiro cai sem que nada tenha regredido.

A correção é aferir a **intenção** (regex ancorado, presença do atributo que
importa), não colar o novo literal — senão o teste quebra de novo na próxima
reformatação. Nunca relaxe a asserção a ponto de ela passar sempre: alternância
frouxa (`/a|b/`) e regex que atravessa o arquivo com `[\s\S]*?` viram decoração.

**Prove por mutação, sempre.** Desfaça a correção no fonte, confirme que o teste
falha, restaure, confirme que passa:

```bash
# remover TODAS as ocorrências do marcador, não a primeira
python -c "import io;p='<arquivo>';s=io.open(p,encoding='utf-8').read();\
io.open(p,'w',encoding='utf-8',newline='').write(s.replace('<marcador>','<quebrado>'))"
```

Substituir só a primeira ocorrência deixa o guard vivo pela segunda e o teste passa
verde — você conclui que a asserção é decorativa quando o defeito é da mutação.
Guarde cópia do arquivo antes e restaure ao fim.

**Desfaça a mutação pela operação inversa, não por `git checkout -- <ficheiro>`.**
Com workers concorrentes no mesmo checkout, restaurar a partir do `HEAD` descarta
qualquer escrita não-commitada de outro card que tenha entrado no ficheiro durante a
sua medição — e a guarda de comandos destrutivos bloqueia esse caminho justamente
por isso. Aplique o `replace` ao contrário (quebrado → marcador) e confirme com
`git status --porcelain` que a árvore voltou a bater com o `HEAD`.

Mutação é também a única prova aceitável de que a correção **chegou ao commit**:
rode-a contra o ficheiro já commitado, não contra o disco. Vermelho com o defeito
reposto e verde ao restaurar fecha a questão que `git show :<ficheiro>` abre.

## Quando o revisor reprova e ele está certo

Reprovação de auditor sobre trabalho seu se responde com a causa mecânica, não com
nova tentativa silenciosa. Escreva no card o que de facto aconteceu (o commit levou
só o teste porque a escrita concorrente igualou o índice ao `HEAD`), o que passou a
ser verificado antes de fechar, e a prova nova — índice inspecionado e mutação
vermelha/verde. Refazer o commit sem nomear o erro faz o mesmo revisor gastar o
turno seguinte a descobrir de novo.

E separe a correção do sintoma da **causa raiz**: cards com workspace efémero a
escrever na árvore real reproduzem isto a cada par de workers no mesmo ficheiro.
Corrigir o commit não fecha essa porta; diga-o em vez de deixar a cadeia parecer sã.

### Teste que proíbe o que o card acabou de construir

Guard antigo ("o endereço nunca pode ficar dentro de uma gaveta") fica obsoleto
quando o trabalho novo implementa exatamente aquilo. Não apague o teste: **reescreva
para guardar a razão original** — no exemplo, os `required` continuam, não pode ser
`<details>` (que remove nós do DOM), e o resgate do submit tem de existir. Apagar o
guard perde a proteção; mantê-lo como estava bloqueia trabalho legítimo.

Ao ancorar asserção em marcador que também aparece em comentário do próprio código,
ancore por início de linha (`/^\s*<details/m`) — senão a prosa que explica *por que
não se usou* aquilo derruba o teste.

## 6. Fechar o board com o que ficou por fazer

No comentário de fechamento, separe **verificado** de **não verificado**, com o
motivo. Confirmação visual que não aconteceu, atalho cujo marcador não apareceu no
bundle e auditoria que não rodou são itens em aberto — descrevê-los como entregues
é o que faz o usuário confiar em cobertura que não existe.

Achado roteado para um id de card que ninguém criou fica órfão indefinidamente.
Antes de fechar, confirme no board que cada id citado existe de fato; se não existir,
crie o card com assignee válido em vez de repetir o id em prosa.

### Varra `blocked` antes de declarar o quadro vazio

`running` e `ready` vazios não são quadro limpo: card bloqueado por assignee
inexistente fica invisível nas duas listas e leva dentro de si achados reais que
ninguem mais está a ver. Liste `blocked` no fechamento e, para cada um, decida
explicitamente entre **desbloquear** e **manter bloqueado com o porquê escrito** —
bloqueio sem justificação registada é desbloqueado mais tarde por parecer
esquecimento, e duplica revisão de código já publicado.

Antes de repassar um achado que dormiu num card bloqueado, verifique-o no código:
outro worker pode tê-lo resolvido e **documentado no próprio ficheiro**. Dívida com
comentário explicando a decisão e teste a cobrir deixou de ser dívida.

### Incoerência aparente entre dois ficheiros pode ser dois contratos

O mesmo dado tratado de formas opostas em sítios diferentes (`Math.abs` num,
ausente noutro) não é defeito por si: quem **desenha** precisa de magnitude, quem
**soma** precisa do sinal. Antes de abrir card de «incoerência», pergunte o que
cada lado faz com o valor — uniformizar os dois destrói um deles.

### Pedir decisão não é obter decisão

Commit de trabalho não-commitado, escolha de produto e medição contra ambiente
real são do dono do repositório. Enuncie o risco concreto uma vez («um `git
checkout` acidental apaga N ficheiros de X cadeias»), registe no board, e siga o
trabalho que não depende disso. Repetir o mesmo pedido a cada volta não acelera a
decisão e enterra o resto do relatório.
