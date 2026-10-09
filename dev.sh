#!/usr/bin/env bash
# The dev server, and the mix commands that need the same environment.
#
#   ./dev.sh            start the server on port 8080 (PORT=8081 moves it)
#   ./dev.sh iex        start it inside IEx
#   ./dev.sh doctor     check this checkout (mix lumen_viae.doctor)
#   ./dev.sh mix ARGS   any mix command, with .env loaded
#
# .env is loaded with `set -a; source`, so values may hold spaces and
# quotes. Without it the AWS keys are missing and the audio players
# silently vanish, which is why this script exists. DEV_DATABASE picks a
# copy of the dev database (see CLAUDE.md, "Local Development"). In a
# worktree set up by the workspace manager, .wt.env sets PORT,
# DEV_DATABASE and MIX_TEST_PARTITION for that worktree; it loads first so
# variables already in the environment still win.
set -euo pipefail

cd "$(dirname "$0")"

if [ -f .wt.env ]; then
  while IFS='=' read -r key value; do
    case "$key" in '' | \#*) continue ;; esac
    [ -n "${!key:-}" ] || export "$key=$value"
  done < .wt.env
  echo "Loaded .wt.env (port ${PORT:-8080}, database ${DEV_DATABASE:-lumen_viae_dev})"
fi

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
  echo "Loaded .env"
else
  echo "Warning: no .env file; audio playback and recording will not work" >&2
fi

if command -v pg_isready >/dev/null 2>&1 && ! pg_isready -q -h localhost; then
  echo "Postgres is not answering on localhost. Start it, then run this again." >&2
  exit 1
fi

if [ -n "${DEV_DATABASE:-}" ]; then
  echo "Using database ${DEV_DATABASE}"
fi

case "${1:-server}" in
  server) exec mix phx.server ;;
  iex) exec iex -S mix phx.server ;;
  doctor) exec mix lumen_viae.doctor ;;
  mix) shift; exec mix "$@" ;;
  *)
    echo "Usage: ./dev.sh [server | iex | doctor | mix ARGS]" >&2
    exit 64
    ;;
esac
