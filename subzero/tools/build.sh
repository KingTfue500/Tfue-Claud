#!/usr/bin/env bash
# Baut build/SubZero.rbxl: Rojo (Skripte, Remotes, Einstellungen) + Lune (Map, Licht, SoundGroups)
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
rojo build default.project.json --output build/SubZero.rbxl
lune run tools/bake.luau build/SubZero.rbxl
