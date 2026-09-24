---
name: hud-local-omniroute
description: HUD local sobre OmniRoute, kanban e vault.
---

# HUD local sobre OmniRoute / Hermes

Use ao construir ou alterar um dashboard/HUD web local sobre o OmniRoute, o
kanban do Hermes ou o vault Obsidian desta máquina.

O HUD vive em `~/Documents/IGOR/ignia-hud` (Express + three.js, porta 7400).
`./iniciar.sh` sobe somente leitura; `--escrita` arma as ações.

## Fontes de dados verificadas

| O quê | Onde | Observação |
|---|---|---|
| Combos, providers, call_logs, context_exchanges, compression_combo | `~/.omniroute/storage.sqlite` | SQLite; abrir somente leitura |
| Cards e papéis | `~/AppData/Local/hermes/kanban.db` | papel derivado do assignee |
| Skills | `~/AppData/Local/hermes/skills/*/*/SKILL.md` | frontmatter YAML |
| Notas | `~/Documents/Obsidian Vault/IGNIA_AI` | 56 notas, links `[[wiki]]` |
| Saúde do roteador | `http://127.0.0.1:20128/api/health` | único endpoint sem auth |

O resto de `/api/*` do OmniRoute exige management token: **escrita vai por CLI**,
não por HTTP.

## Schema dos combos e reconstrução do fallback

A cadeia de fallback **não** vive numa tabela de passos: vive no JSON da coluna
`combos.data` (`{name, strategy, enabled, models:[{id, model, providerId}]}`).
Não existe `combo_models` — conferir `sqlite_master` antes de escrever a query.

Em `call_logs`, para reconstruir o que aconteceu numa requisição:

- **`correlation_id` agrupa as tentativas de UMA requisição.** É por ele que o
  fallback fica visível (`opus:502 → sonnet:502 → gemini:200`).
- `combo_execution_key` agrupa por PASSO da cadeia, não por requisição. Usá-lo
  para fallback produz números sem sentido (centenas de "tentativas" por grupo).
- `combo_step_id` casa com `models[].id` do JSON — é a junção entre configuração
  e uso real, e permite mostrar elos declarados que nunca foram acionados.

Métricas que respondem se a arquitetura se paga: execuções que usaram fallback,
quantas foram salvas por um elo seguinte, e profundidade média (1.00 = o
primário aguenta sozinho).

## Subcomandos do CLI que não funcionam sem token

`combo list/create/delete` leem o banco e funcionam. Já `health` e `quota` falam
com a API HTTP autenticada e respondem **"Server not running. Start with:
omniroute serve" mesmo com o roteador no ar** — a causa real é 401 em `/api/*`,
a mensagem mente sobre isso. Não exponha essas ações no HUD: use `/api/health`
(público) para saúde e leia o resto direto do storage.sqlite.

## Escrever no OmniRoute

Executar o entrypoint `.mjs` com o node atual, nunca o nome `omniroute` do PATH
(no Windows resolve para um shim `.cmd` que só roda com `shell: true`):

```js
execFile(process.execPath,
  [`${APPDATA}/npm/node_modules/omniroute/bin/omniroute.mjs`, 'combo', 'create', nome, '--models', lista],
  { shell: false, env: envDoCli() })
```

Duas armadilhas que custaram diagnóstico:

- **O CLI sai com código 0 mesmo quando falha.** Imprime `Failed to create combo
  (HTTP 400)` e encerra normalmente. Sempre inspecionar a saída além do exit code.
- **Sanitizar o env do filho.** O servidor lê `PORT` para escutar e o CLI lê
  `PORT` para achar o roteador: herdar o env faz o CLI bater no próprio HUD e
  devolver um 403 confuso. Remover `PORT`, `HOST` e as variáveis do próprio app.
- A saída vem com ANSI e três linhas de `Loaded env from` / `is ignored,` em toda
  execução — filtrar antes de mostrar na tela.

## Frontend sob CSP restrita

Com `style-src 'self'` (sem `unsafe-inline`), o que é bloqueado é **apenas**
`setAttribute('style', ...)` e o atributo `style=` no HTML. Continuam funcionando:
`el.style.prop = v` (CSSOM), `setProperty`, custom properties e
`adoptedStyleSheets`. Ou seja: mover estilos estáticos para classes e deixar no JS
só o valor realmente dinâmico (largura/altura de barra).

Servir o three.js de `node_modules/three/build/` como rota estática — o
`three.module.js` importa `./three.core.js`, então **as duas** rotas são
necessárias. Assim não há CDN na policy.

## Parsing de vault e skills

Os arquivos são **CRLF**. Um `\r` no fim da linha quebra o flow seq do YAML
(`tags: [moc, home]\r` falha), e `indexOf('\n---')` acha o fecho errado.
Normalizar `\r\n` → `\n` antes de localizar o delimitador e antes do parse.

Usar parser YAML real (`yaml`), não regex: as skills usam listas em bloco,
escalares multi-linha (`|`, `>`) e chaves aninhadas (`related_skills` costuma
viver sob `metadata`). Buscar as chaves em qualquer profundidade.

Cachear o grafo em memória — reler 300 arquivos por request é inviável.

## Provar que funciona

Teste de API não vê erro de módulo ES, violação de CSP nem WebGL quebrado. Rodar
Chrome headless por CDP (`--headless=new --enable-unsafe-swiftshader`) e:

- contar elementos renderizados por painel (não só status 200);
- capturar `securitypolicyviolation` na página — dá diretiva, arquivo e linha,
  muito mais preciso que raspar o console;
- para provar que o canvas 3D desenhou, `readPixels` e contar pixels claros. Isso
  **exige `preserveDrawingBuffer: true`** no WebGLRenderer, senão volta tudo preto;
- emular 390px com `Emulation.setDeviceMetricsOverride` e verificar overflow e
  largura dos painéis;
- no cleanup, o Crashpad segura arquivos do perfil por ~1s após o kill: esperar e
  usar `maxRetries`, senão EBUSY derruba um teste que passou.

A suite de escrita deve criar e apagar um combo real e conferir que a contagem
volta ao valor original — sem isso não há prova de que o caminho de controle funciona.

## Canvas dentro de aba escondida

Um canvas dentro de `[hidden]` mede 0x0. Ao voltar para a aba é preciso re-medir
e redesenhar (`setTimeout(..., 0)` depois de remover o hidden), senão a tela
volta em branco. Vale teste dedicado: sair da aba, voltar, contar pixels.

Para canvas 2D grande (uma faixa por item), dimensionar a altura pelo número de
itens e reagir a resize com debounce — o `getBoundingClientRect` da área visível
não basta.

## Tela nova que vira a inicial quebra as suites antigas

Ao adicionar uma tela e torná-la a primeira aba, toda suite que assumia qual aba
abre primeiro passa a falhar com "nenhum elemento renderizado". Fazer cada suite
navegar explicitamente até a tela que ela cobre, em vez de confiar no padrão.

## Heredoc no git-bash

`cat <<'EOF'` com JS/CSS dentro engasga no git-bash quando o conteúdo tem aspas
em certas combinações (`unexpected EOF while looking for matching`). Para gerar
arquivo com código, usar `write_file`, não heredoc.

## Matar servidor órfão no Windows

`pkill -f` do MSYS frequentemente não mata o node que segura a porta, e aí testa-se
código antigo sem perceber. Usar:

```bash
netstat -ano | grep ":7400.*LISTENING" | awk '{print $NF}' | sort -u |
  while read pid; do MSYS2_ARG_CONV_EXCL="*" taskkill /PID $pid /F; done
```

`MSYS2_ARG_CONV_EXCL="*"` é obrigatório, senão o bash converte `/PID` em caminho.
