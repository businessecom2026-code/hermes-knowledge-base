---
name: instalacao-skills-terceiros
description: Use ao instalar skill de repo GitHub no Hermes.
---

# Instalar skill de terceiros no Hermes

Skills públicas são escritas para Claude Code / Cursor / plugins. Copiar a pasta direto para `~/AppData/Local/hermes/skills/<categoria>/` quase sempre quebra em silêncio. Siga a ordem abaixo.

## 1. Auditar antes de copiar

```bash
gh api repos/<owner>/<repo> --jq '"\(.stargazers_count)★ \(.pushed_at) \(.description)"'
```

Clone raso num scratch (`$LOCALAPPDATA/Temp/...`, NÃO `/tmp`, para que python/node nativos consigam ler o path) e varra `scripts/` por download e exec dinâmico:

```bash
grep -rIn 'curl |wget |child_process|subprocess|os\.system|base64 -d|urllib|requests\.get' <repo>/skills
```

Auditoria da Snyk (fev/2026) achou falha de segurança em 36,8% das skills públicas. SKILL.md e `scripts/` são código não confiável.

**Licença é critério de recusa, não detalhe.** Verifique antes de clonar:

| Licença | Decisão |
|---|---|
| MIT / Apache-2.0 / BSD | instalar |
| `NOASSERTION` | ler o arquivo — pode ser MIT custom ou não-comercial |
| PolyForm Noncommercial, CC-BY-NC | **recusar** — proibido em trabalho de cliente |
| sem arquivo de licença | **recusar** — todos os direitos reservados por padrão |

`gh api repos/<o>/<r> --jq .license.spdx_id` devolve `NOASSERTION` tanto para MIT reescrito quanto para PolyForm. Sempre abra o arquivo.

## 2. Deduplicar por hash antes de instalar

Vários repos redistribuem o mesmo SKILL.md com outro nome de pasta. Compare SHA-256 do upstream com o que já existe localmente antes de instalar — evita cópias redundantes e colisão de `name:`.

```python
import hashlib
h = lambda p: hashlib.sha256(open(p,'rb').read()).hexdigest()
```

## 3. Corrigir paths de plugin hardcoded

O erro mais comum. Procure e reescreva para o path real da skill instalada:

| Padrão upstream | Origem |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/.claude/skills/<x>/scripts/...` | plugin Claude Code |
| `.agent/skills/<x>/scripts/...` | convenção Agent Skills |
| `.claude/skills/<x>/...` | projeto Claude |
| `npx <cli> ...` | CLI do próprio repo |

Substitua por `$HOME/AppData/Local/hermes/skills/<categoria>/<skill>/scripts/...`. Patchar SOMENTE o SKILL.md não basta: os arquivos em `reference/` repetem os mesmos comandos. Varra toda a árvore `.md` da skill e confirme residual zero.

## 4. `name:` do frontmatter tem que bater com o nome da pasta

O loader do Hermes indexa pelo campo `name:`. Se você instalou em pasta com prefixo para evitar colisão (`uupm-design`, `emil-prototype`, `vercel-composition-patterns`), edite o `name:` junto — senão duas skills disputam o mesmo identificador e `skill_view` carrega a errada.

Valide o catálogo inteiro depois de instalar: para cada SKILL.md, `name` do frontmatter == `os.path.basename(dir)`, e nenhum `name` duplicado no catálogo todo.

## 5. Skill com binário externo

Algumas skills (ex.: impeccable) trazem um launcher que baixa uma engine de GitHub Releases na primeira execução. Isso falha em sessão de agente por permissão/rede. Baixe manualmente para o cache que o launcher espera e **confira o SHA-256 contra o arquivo `.sha256` do release** antes de usar:

```bash
gh release view <tag> -R <owner>/<repo> --json assets --jq '.assets[].name'
curl -fsSL -o <bin> <url> && curl -fsSL -o <bin>.sha256 <url>.sha256 && sha256sum <bin>
```

## 6. Provar que funciona

Não declare instalado sem executar. Rode o script/detector da skill contra um arquivo de teste real e confira a saída. Depois carregue com `skill_view(name)` para confirmar que o loader enxerga.

## 7. Atualizar a DESCRIPTION.md da categoria

`<categoria>/DESCRIPTION.md` é o que o agente lê para decidir se entra na categoria. Adicionar dezenas de skills sem atualizar essa linha deixa metade invisível na prática.

## Antipadrões

- Instalar sem ler a licença. **PolyForm Noncommercial** e ausência de arquivo de licença (= todos os direitos reservados) barram uso comercial — recuse mesmo com 5k★.
- Instalar skill isolada que referencia skill irmã pelo nome (`add-component` → `add-backend`): o fluxo quebra no meio. Traga o conjunto.
- Copiar `.claude/`, `.cursor/`, `.agents/` inteiros do repo — costumam ser cópias espelhadas da mesma skill; escolha UMA árvore.
- Instalar o repo inteiro (o do impeccable tem 76 MB, sendo 14 MB de testes); copie só o diretório da skill.
- Confiar no README para saber quais skills existem; liste o diretório.
- Usar `/tmp` no Windows para clone que ferramenta nativa vai ler.

## Skills relacionadas

- `devops/hud-local-omniroute` — estado local do Hermes
- `process/find-skills` — descobrir skills novas
