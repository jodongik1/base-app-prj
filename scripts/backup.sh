#!/usr/bin/env bash
# 사용: bash scripts/backup.sh [출력 디렉터리]
set -euo pipefail
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"
env_file="$project_dir/.env"

if [[ ! -f "$env_file" ]]; then
  printf '.env 파일이 없습니다. bash setup.sh를 먼저 실행하세요.\n' >&2
  exit 1
fi

compose=(docker compose --env-file "$env_file" -f "$project_dir/compose.yaml")
"${compose[@]}" config --quiet

# 기본 백업 위치는 Git 저장소 밖입니다.
output_dir="${1:-$(dirname "$project_dir")/$(basename "$project_dir")-backups}"
mkdir -p "$output_dir"
backup_dir="$(mktemp -d "$output_dir/$(date +%Y%m%d_%H%M%S)-XXXXXX")"
backend_was_running=false
redis_rewrite_previous=""

finish() {
  result=$?
  trap - EXIT
  if [[ -n "$redis_rewrite_previous" ]]; then
    "${compose[@]}" exec -T redis sh -c 'redis-cli -p "$REDIS_PORT" CONFIG SET auto-aof-rewrite-percentage "$1" >/dev/null' sh "$redis_rewrite_previous" || result=1
  fi
  if [[ "$backend_was_running" == true ]]; then
    "${compose[@]}" start backend >/dev/null || result=1
  fi
  if [[ "$result" -ne 0 ]]; then
    printf '백업 실패: 불완전한 파일이 %s 에 남아 있습니다.\n' "$backup_dir" >&2
  fi
  exit "$result"
}
trap finish EXIT

if [[ -n "$("${compose[@]}" ps --status running -q backend)" ]]; then
  backend_was_running=true
  "${compose[@]}" stop backend >/dev/null
fi

printf '[1/3] PostgreSQL 백업\n'
"${compose[@]}" exec -T postgres sh -c \
  'exec pg_dump -U "$POSTGRES_USER" -p "$POSTGRES_PORT" -Fc "$POSTGRES_DB"' \
  > "$backup_dir/postgres.dump"

printf '[2/3] MongoDB 백업\n'
"${compose[@]}" exec -T mongodb sh -c \
  'exec mongodump --port "$MONGO_PORT" -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase "$MONGO_AUTH_SOURCE" --db "$MONGO_DB" --archive' \
  > "$backup_dir/mongodb.archive"

printf '[3/3] Redis AOF 백업\n'
redis_config_output="$("${compose[@]}" exec -T redis sh -c \
  'redis-cli -p "$REDIS_PORT" --raw CONFIG GET auto-aof-rewrite-percentage' | tr -d '\r')"
redis_rewrite_previous="${redis_config_output##*$'\n'}"
if [[ ! "$redis_rewrite_previous" =~ ^[0-9]+$ ]]; then
  printf 'Redis AOF 재작성 설정을 읽지 못했습니다.\n' >&2
  exit 1
fi
"${compose[@]}" exec -T redis sh -c \
  'redis-cli -p "$REDIS_PORT" CONFIG SET auto-aof-rewrite-percentage 0 >/dev/null'

rewrite_ready=false
for _ in {1..30}; do
  if "${compose[@]}" exec -T redis sh -c \
    'redis-cli -p "$REDIS_PORT" --raw INFO persistence' \
    | tr -d '\r' | grep -q '^aof_rewrite_in_progress:0$'; then
    rewrite_ready=true
    break
  fi
  sleep 1
done
if [[ "$rewrite_ready" != true ]]; then
  printf 'Redis AOF 재작성이 완료되지 않아 백업을 중단합니다.\n' >&2
  exit 1
fi

redis_container="$("${compose[@]}" ps -q redis)"
mkdir -p "$backup_dir/redis/appendonlydir"
docker cp "$redis_container:/data/appendonlydir/." "$backup_dir/redis/appendonlydir/"
test -f "$backup_dir/redis/appendonlydir/appendonly.aof.manifest"

printf 'complete\n' > "$backup_dir/backup.complete"
printf '백업 완료: %s\n' "$backup_dir"
