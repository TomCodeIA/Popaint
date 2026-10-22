#!/usr/bin/env bash
# Popaint : aperçu 3D des modèles sans Studio (image dans build/preview/<quoi>.png).
# Usage : tools/preview.sh props | companions [filtre] | base | centerpieces | showcase | <chemin dans le jeu>
# "base" et "centerpieces" lisent build/Popaint.rbxl : lance tools/check.sh --quick avant.
set -euo pipefail
cd "$(dirname "$0")/.."
WHAT="${1:-props}"
mkdir -p build/preview
.tools/lune run tools/preview/export.luau "build/preview/$WHAT.json" "$@"
case "$WHAT" in
  base) CELL=700; COLS=1 ;;
  centerpieces) CELL=360; COLS=3 ;;
  showcase) CELL=420; COLS=3 ;;
  *) CELL=220; COLS=8 ;;
esac
python3 -I tools/preview/render.py "build/preview/$WHAT.json" "build/preview/$WHAT.png" "$CELL" "$COLS" 200
