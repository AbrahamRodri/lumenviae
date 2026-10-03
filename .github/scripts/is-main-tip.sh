#!/usr/bin/env bash
# Decides whether the commit being deployed is still the tip of main.
#
# Usage: is-main-tip.sh <sha>     (run inside a checkout, so `origin` exists)
#
# Writes is_tip=true or is_tip=false to $GITHUB_OUTPUT (stdout when unset).
#
# Re-running an older run of main would otherwise deploy that run's commit
# over a newer one, after the newer one's migrations have already run. When
# main has moved on, the newer run owns the deploy, and this says so in the
# log instead of failing. If main's tip cannot be read it fails, so an
# unreadable remote never deploys.
set -euo pipefail

sha="${1:?usage: is-main-tip.sh <sha>}"
out="${GITHUB_OUTPUT:-/dev/stdout}"

tip="$(git ls-remote origin refs/heads/main | cut -f1)"
if [ -z "$tip" ]; then
  echo "::error::Could not read the tip of main from origin; not deploying."
  exit 1
fi

if [ "$sha" = "$tip" ]; then
  echo "$sha is the tip of main; deploying."
  echo "is_tip=true" >> "$out"
else
  echo "::notice::Not deploying $sha: main is now at $tip. The newer run owns the deploy, and deploying this one would put older code over newer migrations."
  echo "is_tip=false" >> "$out"
fi
