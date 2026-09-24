# Base de conhecimento Hermes — skills

Pacote com a base de skills usada no Hermes principal. São ~895 skills
(design, dev, ads, SEO, marca, conteúdo, pesquisa, segurança, compliance,
processo, produtividade e mais).

## Instalar

```bash
git clone https://github.com/OWNER/REPO.git hermes-kb && cd hermes-kb && bash install.sh
```

O instalador:

1. Detecta sozinho onde o Hermes guarda skills (Windows, macOS ou Linux).
2. Copia tudo para lá **sem apagar nada** — se já existir uma skill com o
   mesmo nome, a antiga vira `nome.bak-<data>` ao lado.
3. Mostra no fim quantas skills ficaram disponíveis.

Depois: reinicie o Hermes e rode `skills_list` pra conferir.

## O que tem dentro

| Pasta | Vai para | Conteúdo |
|---|---|---|
| `skills/` | `<hermes>/skills/` | base principal, organizada por categoria |
| `hermes-skills-extra/` | `<hermes>/skills/` | skills que só existiam no diretório legado |
| `agents-skills/` | `~/.agents/skills/` | skills de agente (Claude Code / caveman etc.) |

## Se o Hermes estiver em outro lugar

```bash
HERMES_HOME=/caminho/do/hermes bash install.sh
```

## Desfazer

As versões anteriores ficam como `*.bak-<data>` no próprio diretório de
skills. Apague ou renomeie de volta manualmente.

## Nota

Não há segredo, token, credencial nem dado pessoal neste pacote — só
documentação, templates e scripts de skill.
