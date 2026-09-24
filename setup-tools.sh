#!/usr/bin/env bash
# setup-tools.sh — instala as ferramentas externas que este ambiente usa.
# Roda depois de setup-hermes.sh. Nada aqui é obrigatório para as skills
# funcionarem: é o ferramental que os agentes chamam no dia a dia.
set -uo pipefail

say() { printf '%s\n' "$*"; }
ok=0; fail=0

need_npm() {
  if ! command -v npm >/dev/null 2>&1; then
    say "ERRO: npm não encontrado. Instale Node.js (https://nodejs.org) e rode de novo."
    exit 1
  fi
}
need_npm

install_npm() {
  local pkg="$1" bin="$2" why="$3"
  if command -v "$bin" >/dev/null 2>&1; then
    say "  já instalado: $bin ($why)"
    ok=$((ok+1)); return
  fi
  say "  instalando $pkg ($why)..."
  if npm install -g "$pkg" >/dev/null 2>&1; then
    say "    ok: $bin"
    ok=$((ok+1))
  else
    say "    FALHOU: $pkg — instale à mão depois: npm install -g $pkg"
    fail=$((fail+1))
  fi
}

say "=== Roteador de modelos (obrigatório para os combos) ==="
install_npm omniroute            omniroute  "roteia combo/* para os modelos reais"

say ""
say "=== Agentes de código usados em paralelo ==="
install_npm @anthropic-ai/claude-code       claude    "Claude Code CLI"
install_npm @openai/codex                   codex     "Codex CLI"
install_npm opencode-ai                     opencode  "OpenCode CLI"

say ""
say "=== Coleta e documentos ==="
install_npm firecrawl-cli    firecrawl  "scraping e pesquisa web"
install_npm @askjo/camofox-browser camofox "browser stealth para páginas bloqueadas"

say ""
say "=== Proteção contra comando destrutivo (dcg) ==="
if command -v dcg >/dev/null 2>&1 || [ -x "$HOME/.local/bin/dcg.exe" ] || [ -x "$HOME/.local/bin/dcg" ]; then
  say "  já instalado: dcg"
  ok=$((ok+1))
else
  say "  NÃO instalado. É o guarda que bloqueia rm -rf e redirect destrutivo."
  say "  Repo: https://github.com/Dicklesworthstone/destructive_command_guard"
  say "  Instale seguindo o README dele e depois registre o hook no config do Hermes:"
  say ""
  say "    hooks:"
  say "      pre_tool_call:"
  say "        - matcher: terminal"
  say "          command: <caminho-do-dcg>"
  say "          timeout: 30"
  say ""
  fail=$((fail+1))
fi

say ""
say "================================================"
say "Ferramentas: $ok ok, $fail pendentes."
say ""
say "Cada uma pode exigir login próprio (claude, codex, firecrawl)."
say "Faça o login de cada uma à mão — não coloque chave em arquivo versionado."
say "================================================"
