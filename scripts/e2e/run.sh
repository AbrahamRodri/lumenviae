#!/usr/bin/env bash
# Runs the smoke test with Playwright from the npx cache, so the repo gains
# no dependency. BASE_URL defaults to http://localhost:8096.
set -euo pipefail

cd "$(dirname "$0")"

exec npx --yes -p playwright sh -c '
  modules="$(dirname "$(dirname "$(readlink -f "$(which playwright)")")")"
  NODE_PATH="$modules" exec node smoke.cjs
'
