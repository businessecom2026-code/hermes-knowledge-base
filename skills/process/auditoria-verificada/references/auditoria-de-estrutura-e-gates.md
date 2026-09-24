# Auditoria de estrutura de frontend, e os gates que ficam depois

Para quando o pedido é "audite/refine a estrutura" em vez de "ache bugs". O alvo não é achado de
runtime — é **erro que atravessaria build, type-check e suíte sem uma única mensagem**. Mede-se
com scripts curtos que ficam no repositório como gate, não com leitura.

## Ordem

1. **Descubra qual frontend está vivo.** Repositório com mais de um app (`apps/web`, pasta de
   plataforma, pasta de backup, `graft/`) não diz qual importa. Decide `git log -1` por pasta e a
   data dos commits, não o nome. Auditar o app morto é o desperdício mais fácil de cometer aqui.
2. **Leia a auditoria anterior antes de medir.** Relatório do mesmo dia costuma existir; repetir
   achado já entregue queima o turno e o relatório novo passa a conter item que já foi corrigido.
   Declare no seu o que ela cobriu e o que sobrou — estrutura de código é justamente o que
   auditoria de execução não olha.
3. **Estabeleça a linha de base executando**: type-check, build e suíte, nessa ordem, e guarde os
   números. Sem isso não há como afirmar depois que seu diff não quebrou nada.
4. **Meça o grafo de imports** (abaixo), a paridade de i18n e as fronteiras de tipo.
5. **Feche cada buraco com a menor mudança aditiva possível** e deixe um gate que falha se ele
   reabrir.
6. **Revalide a lista inteira do passo 3** e mostre as saídas.

## Grafo de imports

O que se quer saber: o que é inalcançável a partir do ponto de entrada real (`index.tsx`/`main.tsx`),
quem tem fan-in alto (mudança ali propaga), quem tem fan-out alto (candidato a quebra) e quais
especificadores não resolvem.

Regras do instrumento, todas aprendidas errando:

- **Resolva `import()` dinâmico.** `lazy(() => import('./pages/X'))` é a forma normal de carregar
  tela grande; instrumento que só entende `from '...'` marca todas elas como mortas.
- **Não use um regex só.** A alternativa de `from` com `[\s\S]*?` atravessa o arquivo e consome os
  `import()` que vêm depois. Padrões separados, ancorados com `^\s*` e flag `m`.
- **Inclua `.css` e `.jsx`/`.js`.** Um `.tsx` que importa `./X` pode estar resolvendo um `.jsx`;
  varrer só `.ts/.tsx` esconde exatamente a fronteira sem tipo do próximo bloco.
- **Cubra `index.<ext>` de diretório** na resolução, senão pasta com barril vira "não resolvido".
- **Compare o total de alcançáveis com o que você sabe que o app carrega** antes de publicar
  número. Divergência grande é bug seu, não achado.

Não itere `grep -rl` por arquivo em shell para achar quem importa quem: em repositório com
`node_modules` isso estoura o tempo e devolve resultado parcial que parece completo. Um script que
lê cada arquivo uma vez e monta o mapa reverso resolve em segundos.

### Classificar órfão antes de recomendar nada

Três categorias, e só uma é lixo:

| categoria | como identificar | ação |
|---|---|---|
| acervo registrado | doc do projeto declara a árvore ("fonte registrada", hash, "byte a byte") | **não tocar**, nem para corrigir |
| config fora do grafo | lido por ferramenta, não importado (`vite.config`, `*-env.d.ts`) | esperado; isentar no gate |
| morto de verdade | fora dos dois casos acima | propor remoção |

Confirme também que o acervo não custa bytes: procure no build uma string exclusiva dele. Import de
uma única constante traz a constante e o empacotador descarta o resto — nesse caso o "peso" do
arquivo é zero e a severidade do achado cai a nada.

O gate isenta acervo e config **por padrão de caminho** e falha só fora deles. Gate que conta
órfãos sem essa distinção falha para sempre no primeiro dia e é desligado no segundo.

## Fronteira de tipos com arquivo sem anotação

Sintoma: `tsc --noEmit` sai 0 e ninguém confere as props que cruzam para um `.jsx`/`.js`.
Mecanismo: com `allowJs: false` o compilador resolve o módulo e o tipa `any`; o TS7016 que deveria
aparecer fica suprimido por `noImplicitAny: false`.

Prova em dois passos:

1. Sonda fora do projeto, sob flags estritas, importando o módulo — deve acusar o implícito `any`.
   Rode com `--ignoreConfig`, senão o `tsconfig` da pasta é carregado e o erro não aparece.
2. Depois de escrever a declaração, sonda com uso **errado** e uso **real** no mesmo arquivo: o
   errado tem de falhar, o real tem de passar. Tipo que só passa é decoração.

Escreva a declaração **ao lado** da fonte (`X.d.ts` junto de `X.jsx`), aditiva, com as props e os
defaults lidos da própria fonte, e um comentário dizendo por que a fonte não pode ser editada.
União onde o uso real divergir do default (`number | string` quando a chamada passa `var(--token)`)
— o objetivo é aceitar o código que existe e barrar o engano, não forçar refatoração.

Confira ainda o **conjunto verificado**: `tsc --noEmit --listFiles` filtrado ao projeto. Arquivo de
raiz que só entra por ser importado deve ser listado explicitamente no `include`; deixe registrado
no próprio `tsconfig` o motivo de cada exclusão deliberada (config de build entra em Node e traria
tipos de cliente para o programa do browser — verifique-a à parte).

## Paridade de dicionários de i18n

Falha invisível: com fallback (`t()` caindo para o idioma base), chave faltando não quebra nada — o
visitante estrangeiro lê uma frase no idioma errado e ninguém descobre. Compare as chaves de cada
dicionário contra o base e reporte **faltantes e extras** (extra costuma ser erro de digitação que
nunca será lido). Saia diferente de zero: é o único lugar onde essa lacuna dói a tempo.

Dicionários inline num arquivo de contexto se delimitam pelo `const <nome>...= {` e pela primeira
linha `};` — ancore assim em vez de tentar equilibrar chaves.

## Forma dos gates

- Um script por pergunta, em `scripts/`, com comentário no topo dizendo qual erro ele impede.
- Saída legível primeiro (tabelas, contagens), veredito por último, `process.exit(1)` na falha.
- Entradas próprias em `package.json` mais uma agregadora (`check:structure`) que roda todas.
- **Valide cada gate plantando a violação** e removendo depois. Sem o par falha/passa, o gate não
  foi testado.

## Cuidados de edição

- `tsconfig`/`jsonc` têm comentários: ferramenta que valida JSON estrito recusa a escrita. Edite
  por substituição de trecho ancorado, preservando os comentários.
- Arquivo CRLF editado por script ganha linhas LF e o `git diff` acusa mudança de fim de linha por
  todo o arquivo, escondendo o diff real. Depois de editar, conte `\r\n` contra `\n` e normalize
  para o padrão do arquivo.
- Remova sonda e arquivo temporário antes de fechar, e confirme com `git status` que o diff final é
  só o que você quis.

## Falsos positivos frequentes nesta classe

- **`fetch` sem `credentials`** parece sessão esquecida; confira no servidor se a rota tem guarda.
  Rota pública por design está correta — e a que precisa de sessão você confirma uma a uma.
- **Duas versões da mesma biblioteca no `package.json`** (alias tipo `lib128: npm:lib@0.128`) não
  significam duas no bundle: procure a constante de versão nos artefatos do build. Peso em
  `node_modules` não é peso entregue.
- **Arquivo enorme com muito estado** é escolha de escala, não bug — sobretudo se já sai do bundle
  inicial por carregamento preguiçoso. Vai para a tabela do que não foi feito, com a medida.
