#!/usr/bin/env bash
# Popaint : installe les outils de vérification et de construction (une seule fois par machine).
#   - Lune      : exécute les tests et fabrique le fichier de jeu build/Popaint.rbxl
#   - luau-lsp  : vérifie tout le code (types Roblox, mode strict)
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .tools
if [ ! -x .tools/lune ]; then
  curl -sSL -o .tools/lune.zip https://github.com/lune-org/lune/releases/download/v0.8.9/lune-0.8.9-linux-x86_64.zip
  unzip -o -q .tools/lune.zip -d .tools && rm .tools/lune.zip
fi
if [ ! -x .tools/luau-lsp ]; then
  curl -sSL -o .tools/lsp.zip https://github.com/JohnnyMorganz/luau-lsp/releases/download/1.53.0/luau-lsp-linux-x86_64.zip
  unzip -o -q .tools/lsp.zip -d .tools && rm .tools/lsp.zip
fi
chmod +x .tools/lune .tools/luau-lsp
.tools/lune --version
.tools/luau-lsp --version
echo "Outils prêts."
