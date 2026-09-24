# Publicar o Ecom360 no Railway

Depois de `railway`, o repo tem DOIS alvos e um deles é o site que os clientes
veem. Errar o alvo é irreversível na prática.

## 1. Confirme o alvo antes de qualquer push

| | Preview | Site original |
|---|---|---|
| Projeto Railway | `ecom360co-home-preview` | `Ecom360co-Plataforma` |
| Serviço | `home-preview` | — |
| URL | `home-preview-production.up.railway.app` | `ecom360.co` |
| Branch observada | a branch de trabalho | `main` |

**A URL do preview é `home-preview-production`, não `ecom360co-home-preview`.**
O segundo é o nome do PROJETO no Railway e não resolve: devolve 404 com
`{"status":"error","message":"Application not found"}` — erro do roteador do
Railway, não da app. Se vir essa mensagem, confirme o host com
`railway status` antes de investigar o deploy.

Ambos os projetos apontam para o MESMO repositório GitHub; o que os separa é a
branch observada. Por isso publicar no preview é só `git push` na branch de
trabalho — nunca faça merge para `main` para "ver no ar", porque isso publica no
site original.

```bash
railway status            # Project / Linked service / branch observada
railway list              # todos os projetos da conta, para não confundir homónimos
```

O CLI fica linkado a UM projeto por pasta. Rode `railway status` e leia o nome do
projeto antes de `up`, `redeploy` ou qualquer escrita de variável — o link
persiste de sessões anteriores e não há confirmação no comando.

Antes de concluir que uma publicação foi bem, confirme também que o alvo que você
NÃO queria tocar continua de pé (`curl -o /dev/null -w "%{http_code}"`).

## 2. `Online` não significa que o seu código subiu

O modo de falha dominante aqui é silencioso: o serviço responde HTTP 200 e
`railway status` diz `● Online`, enquanto o último deploy está FAILED e quem está
no ar é uma imagem de semanas atrás. O Railway mantém o container antigo rodando
quando o build novo falha — o site nunca cai, e por isso ninguém percebe que a
branch parou de publicar.

**Nunca aceite HTTP 200 como prova de publicação.** Os dois portões que provam:

```bash
# a) o deploy MAIS RECENTE e o que está ATIVO são o mesmo commit?
railway status --json    # latestDeployment.status + activeDeployments[].meta.commitHash
```

```bash
# b) o bundle servido é o que você acabou de construir?
curl -s https://<host>/ | grep -oE 'assets/index-[A-Za-z0-9_-]+\.js'
ls dist/assets/ | grep -E '^index-.*\.js$'
```

O hash do Vite muda com o conteúdo: se os dois baterem, é o seu código. Esse é o
único teste barato que distingue "subiu" de "continua o de antes".

## 3. Ler o log do deploy CERTO

`railway logs --build` sem argumento devolve o log do deploy ATIVO — que, depois
de uma falha, é o antigo. Você lê um build verde de semanas atrás e conclui que
não há erro nenhum. Passe o id explicitamente:

```bash
railway logs --build <DEPLOYMENT_ID>      # id posicional; pegue em `railway status --json`
```

A forma do argumento é rígida: `--deployment-id` não existe, e `--build` com
`--deployment` é rejeitado como conflito. Sinais de que você está lendo log velho:
tempo de build idêntico ao anterior e mesmo `containerimage.digest`.

## 4. Nixpacks chamando `npm ci` num repo pnpm

O repo usa pnpm e não tem `package-lock.json`. O Nixpacks, no default, roda
`npm ci --include=dev`, que aborta:

```
npm error code EUSAGE
The `npm ci` command can only install with an existing package-lock.json
```

O detalhe que denuncia: o próprio build monta cache em
`/root/.local/share/pnpm/store/v3`. O Nixpacks VÊ o `pnpm-lock.yaml` e prepara o
cache certo, mas o comando de instalação continua sendo npm — não confunda a
presença do cache pnpm com gestor correto.

**Editar `railway.json` não resolve.** O serviço usa builder `RAILPACK`, que
ignora config-as-code (o CLI avisa que `railway.json`/`railway.toml` está
depreciado e sai em 2026-12-01). O que pega é variável de ambiente:

```bash
railway variables \
  --set "NIXPACKS_INSTALL_CMD=pnpm install --frozen-lockfile" \
  --set "NIXPACKS_BUILD_CMD=pnpm run build" \
  --skip-deploys
```

`--frozen-lockfile`, não `install` simples: lockfile desatualizado deve parar o
build em vez de ser corrigido em silêncio dentro do contentor. Valide antes de
publicar com `pnpm install --frozen-lockfile --lockfile-only` local.

Regra geral que sobrevive a este caso: quando a config em ficheiro parece ser
ignorada, confirme qual builder o serviço usa em `railway status --json`
(`serviceManifest.build.builder`) antes de reescrever o ficheiro uma segunda vez.

## 5. Disparar um build novo depois de uma falha

**Tente `railway redeploy --yes` primeiro.** Este serviço falha o deploy à
primeira com alguma frequência — aconteceu duas vezes seguidas em commits
diferentes — e o redeploy do MESMO commit sobe limpo. O log de build mostra a
compilação completa e sem erro, o que confirma falha transitória de
infraestrutura, não defeito no código. Não gaste tempo a caçar um bug que não
existe antes de repetir o deploy.

Se o `redeploy` for recusado (`canRedeploy: false` no `status --json`), aí sim
é preciso um build novo:

- corrigir e `git push` na branch observada (dispara sozinho), ou
- `railway up --ci`, que envia o código local e constrói sem depender do commit.

Use `railway up --ci` quando precisar validar uma correção de BUILD sem sujar a
branch com commits de tentativa. Confirme no log que a fase de instalação virou
`pnpm install` antes de comemorar.

## 6. Provar que o CSS/asset novo está no ar

O hash do bundle JS (§2) prova que houve build novo, mas para uma alteração
específica o teste direto é mais barato: procure a regra no ficheiro publicado.

```bash
CSS=$(curl -s https://<host>/ | grep -oE '/assets/index-[A-Za-z0-9_-]+\.css' | head -1)
curl -s "https://<host>$CSS" | grep -c 'a-regra-que-voce-acabou-de-escrever'
```

Para assets binários, o `Content-Length` distingue versões sem baixar nada:

```bash
curl -sI https://<host>/experience/ecom360-logo.glb | grep -i content-length
```

Este portal apanhou uma publicação que parecia boa — home em 200, status
`Online` — mas servia o logo antigo de 2.584.276 bytes em vez dos 604.120 do
commit. Um ficheiro em `public/` que devolve o HTML do fallback SPA (algumas
centenas de bytes, `Cache-Control: no-cache`, `Content-Type: text/html`) também
significa que o asset não subiu.

## 7. O preview não tem base de dados

Não há `DATABASE_URL` no serviço `home-preview`: `/api/settings` e
`/api/settings/logo` devolvem 500 com `ECONNREFUSED ::1:5432`, e o log mostra
`[integrações] falha no ciclo` em repetição. É esperado — o preview existe para
a home, que renderiza completa mesmo assim. Não é regressão e não deve ser
reportado como defeito.

As variáveis `ADMIN_EMAIL` e `ADMIN_PASS_HASH` EXISTEM no Railway. Se rodar
`node server/index.js` local para reproduzir um arranque falhado, sem elas o
servidor aborta com `FATAL: defina ADMIN_EMAIL e ADMIN_PASS_HASH` — isso é a
falta do seu ambiente, não a falha do deploy. Confirme com `railway variables`
antes de concluir o que quer que seja a partir de um teste local.
