#!/usr/bin/env zsh

set -euo pipefail

script_dir="${0:A:h}"
project_root="${script_dir:h}"
cd "$project_root"

if [[ "$(git branch --show-current)" != "main" ]]; then
  echo "Refusing to deploy: switch to main first." >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Refusing to deploy: the working tree is not clean." >&2
  exit 1
fi

node scripts/check-site.mjs
commit_sha="$(git rev-parse HEAD)"

pnpm --allow-build=esbuild --allow-build=workerd dlx wrangler@4.120.0 pages deploy site \
  --project-name office-os \
  --branch main \
  --commit-hash "$commit_sha" \
  --commit-message "Office OS informational product site"
