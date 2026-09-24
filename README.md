# Base de conhecimento Hermes

Tudo que um Hermes novo precisa para trabalhar igual ao original:
**895 skills**, a configuração de roteamento, os 20 profiles especialistas,
os plugins e a lista de ferramentas externas.

Nenhuma chave, token ou dado pessoal está neste repositório.

## Ordem de instalação

```bash
# 1. baixar
git clone https://github.com/businessecom2026-code/hermes-knowledge-base.git ~/hermes-kb
cd ~/hermes-kb

# 2. configuração: provider, profiles, plugins
bash setup-hermes.sh

# 3. ferramentas externas (omniroute, claude, codex, firecrawl...)
bash setup-tools.sh

# 4. a chave, à mão, no .env do Hermes:
#    OMNIROUTE_API_KEY=<sua chave>

# 5. abrir o Hermes e, de dentro dele, instalar as skills:
bash install.sh
```

Os passos 2 e 3 rodam fora do Hermes (pode ser pelo Claude Code).
O passo 5 roda de dentro do Hermes já configurado.

## O que cada script faz

| Script | Faz | Não faz |
|---|---|---|
| `setup-hermes.sh` | provider omniroute, `combo/orchestrator` como padrão, 3 fallbacks, 20 profiles, 2 plugins | não toca em skills, não escreve chave |
| `setup-tools.sh` | instala omniroute, claude, codex, opencode, firecrawl, camofox; avisa sobre o dcg | não faz login por você |
| `install.sh` | copia as 895 skills para o diretório certo | não apaga nada — o que existe vira `.bak-<data>` |

Todos detectam sozinhos onde o Hermes está (Windows, macOS, Linux) e fazem
backup antes de sobrescrever. Para apontar manualmente:

```bash
HERMES_HOME=/caminho/do/hermes bash setup-hermes.sh
```

## Conteúdo

| Pasta | Vai para | O que é |
|---|---|---|
| `skills/` | `<hermes>/skills/` | 300 categorias: design, dev, ads, SEO, marca, conteúdo, pesquisa, security, compliance, processo |
| `agents-skills/` | `~/.agents/skills/` | 172 skills de agente |
| `hermes-skills-extra/` | `<hermes>/skills/` | 4 skills do diretório legado |
| `plugins/` | `<hermes>/plugins/` | agency-agents-router, orca-status |
| `REPOSITORY_CATALOG.md` | — | inventário dos repos de referência. **Listar não autoriza executar**: revise licença, dependências e permissões antes de usar qualquer item |

## Os 20 profiles

**Produtores:** dev, conteudo, copywriter, ads, trafego, seo, pesquisa, marca

**Auditores:** auditordev, auditorconteudo, auditorcopy, auditorads,
auditortrafego, auditorseo, auditorlgpd, auditorsec, auditormarca

**Verificação:** testador, confirmador, sintetizador

Cada um aponta para um `combo/*` do OmniRoute — quem escolhe o modelo real,
faz fallback e controla cota é o roteador.

## Depende de

- **Node.js** (para o `setup-tools.sh`)
- **Python** (para o `setup-hermes.sh` ajustar o config)
- **OmniRoute rodando** em `http://127.0.0.1:20128/v1` — sem ele, todo `combo/*` falha
- **dcg** (opcional, recomendado): bloqueia comando destrutivo antes de executar

## Desfazer

Tudo que foi sobrescrito vira `*.bak-<data>` no mesmo lugar, e o config antigo
fica como `config.yaml.antes-do-setup-<data>`.
