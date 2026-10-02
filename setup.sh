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
  env_temp="$(mktemp "$project_dir/.env.tmp.XXXXXX")"
  trap 'rm -f "$env_temp"' EXIT
  cp "$project_dir/.env.example" "$env_temp"
  mv "$env_temp" "$project_dir/.env"
  trap - EXIT
  printf '.env를 생성했습니다. 로컬 개발용 예시 자격 증명을 확인하세요. 운영용으로 사용하지 마세요.\n'
else
  printf '기존 .env를 유지했습니다.\n'
fi
chmod 600 "$project_dir/.env"

if [[ "$mode" == "--start" ]]; then
  for key in POSTGRES_USER POSTGRES_PASSWORD MONGO_ROOT_USER MONGO_ROOT_PASSWORD MONGO_APP_USER MONGO_APP_PASSWORD REDIS_PASSWORD; do
    if ! grep -Eq "^${key}=.+$" "$project_dir/.env"; then
      printf '.env의 %s 값이 비어 있습니다.\n' "$key" >&2
      exit 1
    fi
  done
  command -v docker >/dev/null || { printf 'Docker is required to start services.\n' >&2; exit 1; }
  docker compose --env-file "$project_dir/.env" -f "$project_dir/compose.yaml" config --quiet
  docker compose --env-file "$project_dir/.env" -f "$project_dir/compose.yaml" up --build
else
  printf '설정 완료 후 실행: bash setup.sh --start\n'
fi
