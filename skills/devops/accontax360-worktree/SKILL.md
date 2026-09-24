---
name: accontax360-worktree
description: Use ao trabalhar no repo Accontax360.
---

# Accontax360: trabalhar sem colidir com o outro terminal

Carrega isto ao tocar em `C:/Users/judon/Documents/IGOR/ecom360co/accontax360`:
preparar worktree, correr testes/build, ou quando aparece vermelho que talvez não
seja teu.

Este repo costuma ter **dois agentes Hermes a trabalhar ao mesmo tempo**. O outro
commita em `main` no meio da tua sessão. Tudo abaixo existe por ter falhado antes.

## 1. Isolar antes de escrever uma linha

```bash
cd C:/Users/judon/Documents/IGOR/ecom360co/accontax360
git worktree add C:/Users/judon/Documents/IGOR/wt-<assunto> -b <area>/<assunto>
```

Nunca editar na árvore principal — o outro terminal tem ficheiros abertos lá.

**Escolher o alvo pelo relógio, não pelo interesse:**

```bash
git log -1 --format='%ar' -- <ficheiro-alvo>
```

Se ele commitou há menos de ~2h nesse ficheiro, está a meio de uma refatoração:
escolhe outro alvo. Entrar ali garante conflito e ainda herdas trabalho por acabar.

## 2. Preparar o worktree (duas armadilhas)

```bash
npm install --include=dev --ignore-scripts --no-audit --no-fund
npx prisma generate --schema apps/api/prisma/schema.prisma
```

- **`--include=dev` é obrigatório.** O ambiente tem `npm config get omit` = `dev`,
  por isso um `npm install` normal não traz `tsc`, `vitest` nem `vite`, e os
  binários parecem simplesmente não existir.
- **Sem `prisma generate`**, toda a suíte de `apps/api` rebenta com
  `Cannot find module '.prisma/client/default'`. Parece código partido; é só o
  client por gerar. Verificar isto ANTES de culpar o próprio trabalho.

Correr as ferramentas por caminho explícito (o `npx` local falha no worktree):

```bash
node node_modules/typescript/bin/tsc -p apps/web/tsconfig.json --noEmit
cd apps/web && node ../../node_modules/vitest/vitest.mjs run
cd apps/web && node ../../node_modules/vite/bin/vite.js build --logLevel error
```

## 3. Vermelho herdado: medir no `main` antes de assumir culpa

O outro terminal muda um componente e **não** atualiza o teste que o lê por texto.
Caso real: o teste exigia a literal `sticky right-0 bg-slate-900` e o código já
dizia `slate-800`.

Antes de tocar em nada:

```bash
git show main:<componente> | grep -c '<literal-que-o-teste-exige>'
git diff main...HEAD -- <componente> | grep -c '<literal>'   # 0 = não foste tu
```

Se já falhava no `main` e o teu diff não toca a linha, **diz isso com o comando que
o prova**. Não escondas nem assumas.

Quando o teste está desactualizado e a decisão do produto está certa, corrige o
TESTE para a intenção, não para a nova literal: `toMatch(/bg-slate-\d{3}/)` em vez
de `toContain('bg-slate-800')`. A cor volta a mudar; o contrato (célula opaca) não.

## 4. Contar a suíte com JSON, não com grep

`grep 'FAIL'` na saída do vitest **mente** — uma corrida deu "5 failed" onde eram 2,
por ruído de execução paralela. Usar sempre:

```bash
node ../../node_modules/vitest/vitest.mjs run --reporter=json --outputFile=<abs>.json
```

e somar `assertionResults` em Python. Referência actual: `apps/api` 3172,
`apps/web` 144.

### Teste que passa sozinho e falha em suíte → procura estado global

A tentação é marcar como "instável" e seguir. Na prática **foi sempre um defeito
real** onde o resultado depende de quem correu antes:

- `localeCompare(x)` **sem locale** usa o do processo — acentos mudam de lugar
  conforme o ICU carregado. Ordenação de NOME exige locale explícito
  (`localeCompare(b, 'pt')`). Comparar data ISO ou código de moeda é seguro sem ele.
- Recharts `Global.isSsr` congela no primeiro import; um teste `node` antes de um
  `jsdom` envenena o seguinte. Repor em `beforeEach`.

Protocolo: correr a suíte 3x. Se falha ~1x, **não é ruído** — procurar a variável
que atravessa ficheiros. Corrigir o CÓDIGO, não afrouxar o teste.

## 5. Antes do push (lição do Railway)

```bash
git status --porcelain | grep '^??'
```

Ficheiro NOVO não rastreado quebra o build remoto com TS2307: quem importa vai, o
módulo importado fica. `tsc` local não apanha porque o ficheiro existe em disco.

## Antipadrões

- Editar na árvore principal "só esta vez".
- Concluir que o repo está partido quando é `prisma generate` em falta.
- Reportar verde escolhendo a corrida que passou, num teste instável.
- Corrigir um teste desactualizado copiando a nova literal para lá.
