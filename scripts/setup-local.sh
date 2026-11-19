#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
if [[ -f .env ]]; then
  echo 'Existing .env preserved. Edit it locally if configuration needs to change.'
  exit 0
fi
umask 077
db_password="$(openssl rand -hex 24)"
access_key="$(openssl rand -hex 32)"
sed -e "s/replace-with-generated-local-password/$db_password/g" \
    -e "s/replace-with-a-random-secret-at-least-24-characters/$access_key/g" \
    .env.example > .env
echo 'Created ignored .env with random local credentials. Add your Agora TEST configuration locally.'
