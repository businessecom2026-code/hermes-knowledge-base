#!/usr/bin/env bash
# setup-hermes.sh — recria a configuração do Hermes (profiles + roteamento).
# NÃO instala skills: isso é o install.sh, rodado depois, de dentro do Hermes.
# NÃO contém chave nenhuma: a OMNIROUTE_API_KEY você coloca à mão no final.
set -euo pipefail

STAMP="$(date +%Y%m%d-%H%M%S)"
say() { printf '%s\n' "$*"; }

# ---- 1. onde fica o Hermes ------------------------------------------------
detect_hermes_home() {
  if [ -n "${HERMES_HOME:-}" ]; then echo "$HERMES_HOME"; return; fi
  for c in \
    "${LOCALAPPDATA:-$HOME/AppData/Local}/hermes" \
    "$HOME/AppData/Local/hermes" \
    "$HOME/.local/share/hermes" \
    "$HOME/.config/hermes" \
    "$HOME/Library/Application Support/hermes"
  do [ -d "$c" ] && { echo "$c"; return; }; done
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) echo "${LOCALAPPDATA:-$HOME/AppData/Local}/hermes" ;;
    Darwin) echo "$HOME/Library/Application Support/hermes" ;;
    *) echo "$HOME/.local/share/hermes" ;;
  esac
}

HD="$(detect_hermes_home)"
say "Hermes em: $HD"
if [ ! -d "$HD" ]; then
  say "ERRO: Hermes não encontrado. Instale o Hermes primeiro, depois rode isto."
  exit 1
fi
mkdir -p "$HD/profiles"

# ---- 2. backup do que já existe ------------------------------------------
if [ -f "$HD/config.yaml" ]; then
  cp "$HD/config.yaml" "$HD/config.yaml.antes-do-setup-$STAMP"
  say "Backup do config atual: config.yaml.antes-do-setup-$STAMP"
fi

# ---- 3. roteamento principal ---------------------------------------------
# Preserva o config existente e só garante provider/model/fallback do OmniRoute.
PY_BIN=""
for c in python3 python py; do
  command -v "$c" >/dev/null 2>&1 || continue
  # no Windows, 'python3' pode ser um atalho falso da Microsoft Store: testa de verdade
  "$c" -c "import sys" >/dev/null 2>&1 && { PY_BIN="$c"; break; }
done
if [ -z "$PY_BIN" ]; then
  say "ERRO: python não encontrado no PATH. Instale python e rode de novo."
  exit 1
fi
say "Usando python: $PY_BIN"

PATCH_PY="$HD/.setup-config-patch.py"
# python nativo do Windows não entende caminho MSYS (/c/...): converte quando existir cygpath
if command -v cygpath >/dev/null 2>&1; then
  HD_NATIVE="$(cygpath -m "$HD")"
  PATCH_PY_NATIVE="$(cygpath -m "$PATCH_PY")"
else
  HD_NATIVE="$HD"
  PATCH_PY_NATIVE="$PATCH_PY"
fi
cat > "$PATCH_PY" <<'PY'
import sys, os, re
hd = sys.argv[1]
p = os.path.join(hd, "config.yaml")
txt = open(p, encoding="utf-8").read() if os.path.exists(p) else ""

block_model = """model:
  provider: omniroute
  default: combo/orchestrator
"""
block_prov = """providers:
  omniroute:
    name: OmniRoute
    api: http://127.0.0.1:20128/v1
    key_env: OMNIROUTE_API_KEY
    transport: chat_completions
    default_model: combo/orchestrator
    discover_models: true
"""
block_fb = """fallback_providers:
  - provider: omniroute
    model: combo/research
  - provider: omniroute
    model: combo/traffic
  - provider: omniroute
    model: combo/fast
"""

def upsert(t, key, block):
    # remove bloco antigo dessa chave (top-level) e acrescenta o novo
    pat = re.compile(r"^%s:\s*\n(?:[ \t\-].*\n|\n)*" % re.escape(key), re.M)
    t = pat.sub("", t)
    return block + t

for k, b in (("fallback_providers", block_fb), ("providers", block_prov), ("model", block_model)):
    txt = upsert(txt, k, b)

open(p, "w", encoding="utf-8", newline="\n").write(txt)
print("config.yaml atualizado (provider omniroute + combo/orchestrator + fallback)")
PY
"$PY_BIN" "$PATCH_PY_NATIVE" "$HD_NATIVE"
rm -f "$PATCH_PY"

# ---- 4. os 20 profiles especialistas -------------------------------------
mk_profile() {
  local name="$1" model="$2" desc="$3"
  local d="$HD/profiles/$name"
  mkdir -p "$d"
  printf 'description: %s\ndescription_auto: false\n' "'$desc'" > "$d/profile.yaml"
  printf 'model:\n  provider: omniroute\n  default: %s\n' "$model" > "$d/config.yaml"
}

say "Criando profiles..."
mk_profile dev             combo/dev              "Implementa software: codigo, arquitetura, teste, banco, front-end."
mk_profile conteudo        combo/content-creation "Produz conteudo editorial: artigo, post, roteiro, newsletter. Aplica voz e mensagem da marca."
mk_profile copywriter      combo/copywriting      "Escreve copy de conversao: headline, landing, oferta, CTA, e-mail. Foca em persuasao, nao em decoracao."
mk_profile ads             combo/ads              "Cria e estrutura campanha de anuncio em Google Ads e Meta Ads. Angulo, criativo, publico."
mk_profile trafego         combo/traffic          "Decide investimento em midia paga: CPA e ROAS a partir da margem, estrutura, escala, diagnostico de funil."
mk_profile seo             combo/seo-aeo-geo      "Otimiza busca organica e mecanismos de resposta: auditoria tecnica, palavra-chave, SEO local, AEO e GEO."
mk_profile pesquisa        combo/research         "Pesquisa e levantamento: concorrencia, mercado, publico, fontes primarias, scraping."
mk_profile marca           combo/content-creation "Estrategia de marca: posicionamento, arquitetura, naming, mensagem, voz, guidelines."

mk_profile auditordev      combo/audit-dev        "Auditor de codigo. Revisa diff, aponta bug, regressao e falta de teste. Nunca revisa o proprio output."
mk_profile auditorconteudo combo/audit-content    "Auditor editorial. Fato, fonte, estrutura, coerencia, profundidade. Nunca revisa o proprio output."
mk_profile auditorcopy     combo/audit-copy       "Auditor de copy. Promessa sustentada, clareza, prova, tom, ausencia de tell de IA. Nunca revisa o proprio output."
mk_profile auditorads      combo/audit-ads        "Auditor de anuncio. Politica de plataforma, promessa versus produto, conformidade de rastreamento. Nunca revisa o proprio output."
mk_profile auditortrafego  combo/audit-traffic    "Auditor de midia paga. Medicao antes de escala, dupla contagem, significancia, teto de CPA. Nunca revisa o proprio output."
mk_profile auditorseo      combo/audit-seo        "Auditor de SEO e AEO/GEO. Auditoria tecnica, indexacao, schema, acesso de crawler de IA. Nunca revisa o proprio output."
mk_profile auditorlgpd     combo/audit-lgpd       "Auditor LGPD. Base legal, consentimento, cookies e pixel, direitos do titular, retencao, incidente. Nunca revisa o proprio output."
mk_profile auditorsec      combo/audit-security   "Auditor de seguranca de aplicacao. IDOR, injecao, XSS, SSRF, sessao, upload, segredo, dependencia. Nunca revisa o proprio output."
mk_profile auditormarca    combo/audit-brand      "Auditor de marca. Consistencia com guideline, voz, posicionamento. Nunca revisa o proprio output."

mk_profile testador        combo/test             "Testador externo. Executa o artefato de verdade e prova que funciona ou quebra. Nunca testa o proprio trabalho."
mk_profile confirmador     combo/confirm          "Confirmador externo. Verifica se o que foi pedido foi entregue e se revisor e testador foram atendidos. Da o veredito de aceite."
mk_profile sintetizador    combo/orchestrator     "Consolida o resultado de varios especialistas num entregavel unico, resolvendo contradicao entre eles."

N=$(ls "$HD/profiles" | wc -l | tr -d ' ')
say "  $N profiles no diretório."

# ---- 5. conferência -------------------------------------------------------
say ""
say "==================== PRONTO ===================="
say "Configurado: provider omniroute, modelo padrão combo/orchestrator, $N profiles."
say ""
say "FALTA VOCÊ FAZER 3 COISAS:"
say ""
say "1) OmniRoute rodando em http://127.0.0.1:20128/v1"
say "   npm install -g omniroute   (depois inicie o serviço)"
say ""
say "2) A chave, no arquivo $HD/.env :"
say "   OMNIROUTE_API_KEY=<sua chave>"
say "   (nunca cole a chave no chat nem em arquivo versionado)"
say ""
say "3) Abra o Hermes e rode o comando de instalar as skills."
say "==============================================="
