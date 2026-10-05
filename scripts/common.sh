#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
dc() { docker compose --project-directory "$ROOT" --env-file "$ROOT/.env" -f "$ROOT/compose.yml" "$@"; }
