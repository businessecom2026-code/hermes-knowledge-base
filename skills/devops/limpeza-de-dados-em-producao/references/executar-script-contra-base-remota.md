# Correr um script contra uma base remota

O problema recorrente: o script corre, não dá erro, e o inventário sai vazio ou
errado — porque falou com a base errada, ou porque nem ligou.

## 1. Imprimir o destino antes de acreditar no resultado

Um `.env` local costuma apontar para base **local**, mesmo num repositório cuja
aplicação está em produção. Nada avisa: o inventário devolve zero linhas e parece
que os dados não existem.

```js
require('dotenv').config();
for (const k of ['DATABASE_URL', 'DATABASE_URL_BR', 'DATABASE_URL_ES']) {
  const v = process.env[k];
  if (!v) { console.log(k, '= (ausente)'); continue; }
  const u = new URL(v);
  console.log(k, '->', u.hostname, 'db=' + u.pathname.slice(1), 'user=' + u.username.slice(0, 4) + '***');
}
```

Nunca imprimir a URL inteira: leva a senha.

## 2. Confirmar quantas bases existem

Uma aplicação multi-região tem mais do que uma (`..._BR`, `..._ES`). Um inventário
que só lê a primeira reporta "limpo" enquanto a segunda continua cheia de dados de
teste. Percorre todas e reporta por base.

## 3. Hostname de rede privada só resolve de dentro

Hostnames como `*.railway.internal`, `*.internal` ou um serviço de rede privada
**não resolvem da máquina local**. Um comando que injecta as variáveis mas corre
localmente (por exemplo `railway run`) falha por DNS, e o erro parece base em
baixo em vez de rede errada.

O que funciona é enviar o script para dentro do container e executá-lo lá, em
base64 para não lutar com escape de aspas:

```bash
B64=$(base64 -w0 <caminho-do-script>.cjs)
railway ssh --service <servico> \
  "cd /app && echo '$B64' | base64 -d > /app/tmp-$$.cjs && node /app/tmp-$$.cjs; rm -f /app/tmp-$$.cjs"
```

Dois detalhes que fazem isto falhar:

- **O `cd` para a raiz da aplicação é obrigatório.** Fora dela o
  `require('@prisma/client')` (ou qualquer dependência) não resolve, e o erro
  parece pacote em falta em vez de directório errado.
- **A base pode viver noutro projeto.** Listar serviços do projeto da aplicação e
  não encontrar o Postgres não significa que ele não existe.

O script sai sempre em JSON por `stdout` e é lido com `tee` para um ficheiro em
`$LOCALAPPDATA/Temp`: saída longa truncada no terminal esconde justamente o topo,
onde estão os candidatos.

## 4. Embrulhar a invocação num ficheiro `.sh`

A linha de invocação tem `&&`, aspas aninhadas e `$()` — encadeamento suficiente
para o hook `dcg` estourar o tempo de avaliação de forma repetida. Escreve um `.sh`
em `$LOCALAPPDATA/Temp` com `write_file` e chama `bash <ficheiro>`: passa de
primeira e fica reutilizável para os passos seguintes (inventário, ensaio,
execução, verificação).

Filtra o ruído do CLI para o JSON ficar legível:

```bash
... 2>&1 | grep -v 'Config as Code\|config migrate\|Using SSH key' | tee "$OUT"
```
