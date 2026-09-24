# Verificar que um deploy está mesmo no ar

"Deploy concluído" no painel não prova que a SUA correção está a ser servida.
Confirme pelo conteúdo do que o navegador descarrega.

Caso de referência: Railway a observar `main`, front Vite/React.

## 1. Validar o build ANTES do push, a partir do índice

`tsc` e `vitest` na árvore de trabalho leem ficheiros que existem em disco mas
podem não estar no commit — ficheiro novo esquecido fora do `git add` quebra o
build remoto com TS2307 e passa despercebido localmente.

Valide o que o servidor vai receber:

```bash
git status --porcelain | grep '^??'          # nada solto?
TREE=$(git write-tree)
DEST="$LOCALAPPDATA/Temp/verify-$(date +%H%M%S)"
mkdir -p "$DEST" && git archive "$TREE" | tar -x -C "$DEST"
cd "$DEST" && npm ci --include=dev --silent && npm run build
```

- **`--include=dev` é obrigatório.** Sem ele o `npm ci` instala só produção,
  `typescript` não vem e o build morre com `'tsc' não é reconhecido` — artefacto
  do diretório temporário, não defeito do código.
- No Windows use `$LOCALAPPDATA/Temp`, não `/tmp`: ferramentas nativas (node,
  git, tar) não traduzem caminhos MSYS.
- **Evite `rm -rf` no comando** — o guardráil pode expirar a avaliação e barrar a
  chamada inteira. Crie destino novo com timestamp em vez de limpar o antigo.

## 2. Capturar a assinatura antes do push

```bash
curl -s https://<dominio> | grep -oE 'assets/index-[A-Za-z0-9_-]+\.js'
```

A mudança desse hash indica que um deploy novo entrou.

## 3. Confirmar que o remoto tem o seu commit

```bash
git ls-remote origin main | head -1   # tem de bater com o seu HEAD
git rev-parse HEAD
```

**NÃO monitore à espera do hash do seu build local.** O servidor builda noutro SO
e gera hash diferente para o mesmo código — um monitor que espera por ele corre
até ao limite sem casar nunca. Compare commits; confirme conteúdo por texto.

## 4. Achar o CHUNK certo (o passo que engana)

Vite parte o bundle por tela e por idioma. Procurar o texto da correção em
`index-*.js` dá **ausente** mesmo com o deploy correto no ar.

Descubra onde o texto vive, no build local que você sabe estar certo:

```bash
cd "$DEST/apps/web/dist/assets"
grep -lF '<texto da correcao>' *.js
# tipicamente: <Tela>-<hash>.js, pt-BR-<hash>.js
```

Extraia o nome correspondente do `index` servido e baixe ESSE:

```bash
IDX=$(curl -s https://<dominio> | grep -oE 'assets/index-[A-Za-z0-9_-]+\.js' | head -1)
CHUNK=$(curl -s "https://<dominio>/$IDX" | grep -oE '<Tela>-[A-Za-z0-9_-]+\.js' | head -1)
curl -s "https://<dominio>/assets/$CHUNK" -o prod.js
grep -cF '<texto da correcao>' prod.js
```

Chunks de idioma (`pt-BR-*.js`) costumam ser **byte-idênticos** entre build local
e remoto quando o código é o mesmo: hash igual é a prova mais forte disponível.

## 5. Verificar lógica minificada

Nomes de variável desaparecem; procure pelo padrão, não pelo identificador:

- flag booleana que se liberta → `grep -oE '\w+\.current=!1\}'`
- classes Tailwind sobrevivem inteiras → `grep -F 'h-0 overflow-hidden opacity-0'`
- strings de copy sobrevivem inteiras → melhor âncora para confirmar uma correção

## 6. Rota protegida

`401` num POST sem sessão é **rota viva e guarda a funcionar**, não falha de
deploy. Para exercitar o corpo de verdade é preciso sessão — se não a tiver, diga
que a verificação foi do código servido e ofereça o teste logado como passo extra,
com horário.

## Push recusado com `Repository not found`

Costuma ser a conta ativa do `gh` a trocar sozinha, não o remote apagado:

```bash
gh auth status
gh auth switch --user <dona-do-repo>
```
