#!/usr/bin/env bash
# Instalador da base de conhecimento (skills) do Hermes.
# Uso:  bash install.sh
# Copia as skills deste repo para o diretório de skills do Hermes local,
# sem apagar nada: o que já existe com o mesmo nome é preservado em .bak-<data>.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

say() { printf '%s\n' "$*"; }

# ---- 1. descobrir onde o Hermes guarda skills ----------------------------
detect_hermes_home() {
  if [ -n "${HERMES_HOME:-}" ]; then echo "$HERMES_HOME"; return; fi
  for c in \
    "${LOCALAPPDATA:-$HOME/AppData/Local}/hermes" \
    "$HOME/AppData/Local/hermes" \
    "$HOME/.local/share/hermes" \
    "$HOME/.config/hermes" \
    "$HOME/Library/Application Support/hermes" \
    "$HOME/.hermes"
  do
    [ -d "$c" ] && { echo "$c"; return; }
  done
  # nada encontrado: usa o padrão do SO
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) echo "${LOCALAPPDATA:-$HOME/AppData/Local}/hermes" ;;
    Darwin) echo "$HOME/Library/Application Support/hermes" ;;
    *) echo "$HOME/.local/share/hermes" ;;
  esac
}

HERMES_DIR="$(detect_hermes_home)"
DEST="$HERMES_DIR/skills"
AGENTS_DEST="$HOME/.agents/skills"

say "Hermes detectado em : $HERMES_DIR"
say "Skills vão para     : $DEST"
say "Skills de agente    : $AGENTS_DEST"
say ""

mkdir -p "$DEST" "$AGENTS_DEST"

# ---- 2. copiar preservando o que já existe -------------------------------
copy_tree() {
  local from="$1" to="$2" label="$3"
  [ -d "$from" ] || return 0
  local n=0 kept=0
  for item in "$from"/*; do
    [ -e "$item" ] || continue
    local name; name="$(basename "$item")"
    if [ -e "$to/$name" ]; then
      mv "$to/$name" "$to/$name.bak-$STAMP"
      kept=$((kept+1))
    fi
    cp -R "$item" "$to/$name"
    n=$((n+1))
  done
  say "  $label: $n itens copiados ($kept versões antigas guardadas como .bak-$STAMP)"
}

say "Copiando..."
copy_tree "$SRC/skills"              "$DEST"        "skills do Hermes"
copy_tree "$SRC/hermes-skills-extra" "$DEST"        "skills extras"
copy_tree "$SRC/agents-skills"       "$AGENTS_DEST" "skills de agente"

# ---- 3. conferir ---------------------------------------------------------
TOTAL=$(find "$DEST" "$AGENTS_DEST" -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
say ""
say "Pronto. $TOTAL arquivos SKILL.md disponíveis."
say "Reinicie o Hermes (ou abra uma sessão nova) e rode: skills_list"
say ""
say "Para desfazer: as versões antigas estão em *.bak-$STAMP dentro de $DEST"
