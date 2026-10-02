#!/usr/bin/env bash
# 사용: bash scripts/restore.sh <backup.sh가 만든 디렉터리>
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"
env_file="$project_dir/.env"

if [[ $# -ne 1 || ! -d "$1" ]]; then
  printf 'Usage: bash scripts/restore.sh <백업 디렉터리>\n' >&2
  exit 2
fi
backup_dir="$(cd "$1" && pwd)"

if [[ ! -f "$env_file" ]]; then
  printf '.env 파일이 없습니다. bash setup.sh를 먼저 실행하세요.\n' >&2
  exit 1
fi

for required_file in \
  "$backup_dir/backup.complete" \
  "$backup_dir/postgres.db" \
  "$backup_dir/mongodb.db" \
  "$backup_dir/postgres.dump" \
  "$backup_dir/mongodb.archive" \
  "$backup_dir/redis/appendonlydir/appendonly.aof.manifest"; do
  if [[ ! -f "$required_file" ]]; then
    printf '백업 파일 누락: %s\n' "$required_file" >&2
    exit 1
  fi
done

compose=(docker compose --env-file "$env_file" -f "$project_dir/compose.yaml")
"${compose[@]}" config --quiet
"${compose[@]}" exec -T postgres pg_restore --list < "$backup_dir/postgres.dump" > /dev/null
database_name="$("${compose[@]}" exec -T postgres printenv POSTGRES_DB < /dev/null)"
mongo_database_name="$("${compose[@]}" exec -T mongodb printenv MONGO_DB < /dev/null)"
if [[ "$(<"$backup_dir/postgres.db")" != "$database_name" || "$(<"$backup_dir/mongodb.db")" != "$mongo_database_name" ]]; then
  printf '백업의 PostgreSQL 또는 MongoDB 이름이 현재 .env와 다릅니다. 복원을 중단합니다.\n' >&2
  exit 1
fi

printf '복원 대상: %s\n' "$database_name"
printf 'PostgreSQL, MongoDB, Redis의 현재 데이터를 덮어씁니다. 계속하려면 DB 이름을 입력하세요: '
read -r confirmation
if [[ "$confirmation" != "$database_name" ]]; then
  printf '복원을 취소했습니다.\n' >&2
  exit 1
fi

backend_was_running=false
helper_id=""
finish() {
  result=$?
  trap - EXIT
  if [[ -n "$helper_id" ]]; then
    docker stop "$helper_id" >/dev/null || result=1
  fi
  if [[ "$backend_was_running" == true ]]; then
    if [[ "$result" -eq 0 ]]; then
      "${compose[@]}" start backend >/dev/null || result=1
    else
      printf '복원이 실패해 백엔드를 중지 상태로 유지합니다.\n' >&2
    fi
  fi
  exit "$result"
}
trap finish EXIT

if [[ -n "$("${compose[@]}" ps --status running -q backend)" ]]; then
  backend_was_running=true
  "${compose[@]}" stop backend >/dev/null
fi

printf '[1/3] PostgreSQL 복원\n'
"${compose[@]}" exec -T postgres sh -ec \
  'dropdb --if-exists --force -U "$POSTGRES_USER" -p "$POSTGRES_PORT" "$POSTGRES_DB"; createdb -U "$POSTGRES_USER" -p "$POSTGRES_PORT" "$POSTGRES_DB"'
"${compose[@]}" exec -T postgres sh -c \
  'exec pg_restore --exit-on-error --no-owner -U "$POSTGRES_USER" -p "$POSTGRES_PORT" -d "$POSTGRES_DB"' \
  < "$backup_dir/postgres.dump"

printf '[2/3] MongoDB 복원\n'
"${compose[@]}" exec -T mongodb sh -ec \
  'mongosh --quiet --port "$MONGO_PORT" -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase "$MONGO_AUTH_SOURCE" "$MONGO_DB" --eval "db.dropDatabase()" >/dev/null'
"${compose[@]}" exec -T mongodb sh -c \
  'exec mongorestore --port "$MONGO_PORT" -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase "$MONGO_AUTH_SOURCE" --nsInclude "$MONGO_DB.*" --archive' \
  < "$backup_dir/mongodb.archive"

printf '[3/3] Redis AOF 복원\n'
"${compose[@]}" stop redis >/dev/null
helper_id="$("${compose[@]}" run -d --rm --no-deps --entrypoint sleep redis 3600)"
docker exec "$helper_id" mkdir -p /restore
docker cp "$backup_dir/redis/appendonlydir" "$helper_id:/restore/"
docker exec "$helper_id" sh -ec '
    test -f /restore/appendonlydir/appendonly.aof.manifest
    previous="/data/appendonlydir.before-restore-$(date +%s)"
    if [ -e /data/appendonlydir ]; then mv /data/appendonlydir "$previous"; fi
    if ! cp -R /restore/appendonlydir /data/appendonlydir; then
      if [ -e "$previous" ]; then mv "$previous" /data/appendonlydir; fi
      exit 1
    fi
    chown -R redis:redis /data/appendonlydir
  '
docker stop "$helper_id" >/dev/null
helper_id=""
"${compose[@]}" start redis >/dev/null
"${compose[@]}" exec -T redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli -p "$REDIS_PORT" ping' | grep -q PONG

printf '복원 완료: %s\n' "$backup_dir"
