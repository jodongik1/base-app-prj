#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mode="${1:-init}"

if [[ "$mode" != "init" && "$mode" != "--start" ]]; then
  printf 'Usage: bash setup.sh [--start]\n' >&2
  exit 2
fi

if [[ ! -f "$project_dir/.env" ]]; then
  umask 077
  postgres_password="$(LC_ALL=C od -An -N24 -tx1 /dev/urandom | tr -d '[:space:]')"
  mongo_password="$(LC_ALL=C od -An -N24 -tx1 /dev/urandom | tr -d '[:space:]')"
  env_temp="$(mktemp "$project_dir/.env.tmp.XXXXXX")"
  trap 'rm -f "$env_temp"' EXIT

  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      POSTGRES_PASSWORD=*) printf 'POSTGRES_PASSWORD=%s\n' "$postgres_password" ;;
      MONGO_ROOT_PASSWORD=*) printf 'MONGO_ROOT_PASSWORD=%s\n' "$mongo_password" ;;
      *) printf '%s\n' "$line" ;;
    esac
  done < "$project_dir/.env.example" > "$env_temp"

  mv "$env_temp" "$project_dir/.env"
  trap - EXIT
  printf 'Created .env with project-specific database passwords. Review ports before starting.\n'
else
  printf 'Existing .env preserved.\n'
fi

if [[ "$mode" == "--start" ]]; then
  if grep -Eq '^(POSTGRES_PASSWORD|MONGO_ROOT_PASSWORD)=change-me-on-setup$' "$project_dir/.env"; then
    printf 'Replace placeholder database passwords in .env before starting.\n' >&2
    exit 1
  fi
  command -v docker >/dev/null || { printf 'Docker is required to start services.\n' >&2; exit 1; }
  docker compose --env-file "$project_dir/.env" -f "$project_dir/compose.yaml" config --quiet
  docker compose --env-file "$project_dir/.env" -f "$project_dir/compose.yaml" up --build
else
  printf 'Start after review: bash setup.sh --start\n'
fi
