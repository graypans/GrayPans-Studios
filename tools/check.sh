#!/usr/bin/env bash
# Full static validation gate: sourcemap -> analyze -> unit tests -> place build.
# Used by Claude during the overnight build and safe to run on any machine with the tools installed.
set -euo pipefail
cd "$(dirname "$0")/.."

DEFS="${PORCELAIN_DEFS:-/usr/local/lib/porcelain-tools/globalTypes.d.luau}"

echo "==> rojo sourcemap"
rojo sourcemap default.project.json -o sourcemap.json

echo "==> luau-lsp analyze"
luau-lsp analyze --definitions="$DEFS" --sourcemap=sourcemap.json src/

echo "==> unit tests"
luau tests/logic.spec.luau > /tmp/porcelain-tests.out 2>&1 || { cat /tmp/porcelain-tests.out; exit 1; }
tail -1 /tmp/porcelain-tests.out

echo "==> rojo build"
mkdir -p dist
rojo build default.project.json -o dist/ProjectPorcelain.rbxlx

echo "ALL CHECKS GREEN"
