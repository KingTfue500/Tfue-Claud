#!/usr/bin/env bash
# Prüft den gesamten Code: luau-lsp (strict, Roblox-Typen) + selene.
# Erwartet luau-lsp und die Roblox-Typdefinitionen (globalTypes.d.luau):
#   LUAU_LSP=/pfad/zu/luau-lsp  ROBLOX_DEFS=/pfad/zu/globalTypes.d.luau  tools/check.sh
set -euo pipefail
cd "$(dirname "$0")/.."
LUAU_LSP="${LUAU_LSP:-luau-lsp}"
ROBLOX_DEFS="${ROBLOX_DEFS:-globalTypes.d.luau}"
rojo sourcemap default.project.json --output sourcemap.json
"$LUAU_LSP" analyze --platform=roblox --sourcemap=sourcemap.json --defs="@roblox=$ROBLOX_DEFS" src
# selene braucht eine Roblox-Std-Datei (roblox.yml) und ist daher optional
if [ "${SELENE:-0}" = "1" ]; then selene src; fi
