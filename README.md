# 앱 기본 템플릿

React + TypeScript + Vite + Tailwind CSS 프론트엔드와 FastAPI 백엔드, PostgreSQL · MongoDB · Redis 인프라로 구성된 풀스택 개발 템플릿입니다.

## 시작하기

**사전 요구사항**: Docker Compose. Docker 없이 앱 코드를 실행하려면 Node.js·pnpm·Python·uv도 필요합니다.

```bash
# 1. .env 생성 (최초 한 번)
bash setup.sh

# 2. .env의 계정·비밀번호, 포트, 공개 주소를 검토
# 3. 설정 완료 후 실행
bash setup.sh --start
```

`.env`가 이미 존재하면 덮어쓰지 않습니다. `.env.example`에는 바로 실행 가능한 로컬 개발용 PostgreSQL·MongoDB·Redis 계정과 비밀번호가 들어 있습니다. 이 값은 저장소에 공개되므로 운영 환경이나 외부 공개 서비스에서는 반드시 교체하세요. `.env`는 Git에서 제외되며 셋업 시 파일 권한을 `600`으로 지정합니다. 기존 데이터 볼륨의 계정·비밀번호는 `.env` 변경만으로 바뀌지 않습니다. 기존 데이터를 유지하려면 DB 내부 계정을 변경하거나 기존 값에 맞게 `.env`를 입력해야 합니다. 특히 MongoDB 앱 계정은 새 볼륨의 최초 초기화 때만 생성됩니다. 모든 서비스는 `.env`의 포트를 호스트와 컨테이너 내부에서 동일하게 사용합니다.

| 서비스 | 주소 |
|--------|----------|
| 프론트엔드 | `http://localhost:<FRONTEND_PORT>` |
| 백엔드 API | `http://localhost:<BACKEND_PORT>` |
| 헬스 체크 | `http://localhost:<BACKEND_PORT>/health` |

`<..._PORT>`에는 현재 `.env` 값을 넣으세요. `HOST_BIND_IP`는 Compose가 웹·API 포트를 호스트에 공개할 주소이고, `POSTGRES_BIND_IP`, `MONGO_BIND_IP`, `REDIS_BIND_IP`는 각 DB의 호스트 공개 주소입니다. `127.0.0.1`은 이 컴퓨터에서만 접근 가능하고 `0.0.0.0`은 모든 호스트 인터페이스에서 접속을 받습니다. 컨테이너 내부 서버의 `0.0.0.0`은 Docker에서 전달한 연결을 받기 위한 별도 설정입니다. Redis는 비밀번호를 설정했지만 인터넷에 직접 공개하지 마세요. 공개가 필요한 서비스는 방화벽과 접근 제어를 별도로 구성해야 합니다.

현재 `compose.yaml`은 Vite 개발 서버용입니다. 운영 배포 구성은 실제 프로젝트의 요구사항이 정해진 뒤 추가하세요.

```bash
# 종료 (데이터 유지)
docker compose down

# 종료 + 데이터 완전 삭제
docker compose down -v
```

## Docker 없이 로컬 실행

DB만 Docker로 실행하고, 앱은 로컬에서 직접 실행합니다. 외부 공개 환경에서는 `.env`의 예시 자격 증명을 먼저 바꾸세요.

```bash
# DB만 실행
docker compose up -d postgres mongodb redis

# 백엔드 (별도 터미널, 프로젝트 루트 기준)
cd backend && uv sync && uv run python -m app.dev

# 프론트엔드 (다른 터미널, 프로젝트 루트 기준)
cd frontend && pnpm install && pnpm dev
```

> 프론트엔드와 백엔드는 루트 `.env`를 읽습니다. 비밀번호에 셸 특수문자가 있어도 백업·복원 스크립트에서 `.env`를 셸 코드로 실행하지 않습니다.

백엔드의 기본 테스트는 `cd backend && uv run python -m unittest discover -s tests -v`로 실행합니다.

## 프로젝트 구조

```
.
├── frontend/
│   └── src/
│       ├── app/          # 앱 진입점 및 화면 구성
│       └── components/   # 공통 UI 컴포넌트를 추가할 위치
├── backend/
│   └── app/
│       ├── api/          # HTTP 라우터
│       ├── core/         # 환경설정 (pydantic-settings)
│       └── infrastructure/  # PostgreSQL · MongoDB · Redis 클라이언트
├── infrastructure/
│   └── compose.yaml      # DB 서비스 단독 실행용
└── scripts/
    ├── backup.sh         # DB 백업
    └── restore.sh        # DB 복원
```

**설계 원칙**

- 모든 설정값은 환경변수로 주입. 환경변수 누락 시 앱 시작 시점에 오류 발생.
- DB 연결은 `backend/app/infrastructure`에 둡니다. 플랫폼별 코드는 실제 대상이 정해지면 추가합니다.
- 백엔드는 세 DB 모두 healthy 상태가 된 후 시작됩니다.

## 데이터 백업 · 복원

```bash
# 백업 (기본 위치: 저장소 밖의 ../<프로젝트명>-backups/)
bash scripts/backup.sh

# 특정 경로에 저장
bash scripts/backup.sh ../my-backups

# 복원: 대상 DB 이름을 다시 입력해야 진행됩니다
bash scripts/restore.sh ../my-backups/<백업 디렉터리>
```

백업 중에는 이 템플릿의 백엔드를 잠시 중지해 쓰기를 멈춥니다. 외부에서 DB에 직접 쓰는 프로그램이 있다면 별도로 중지해야 세 저장소 간 시점을 맞출 수 있습니다. 백업에는 DB 이름을 함께 기록하며, 현재 이름과 다르면 복원을 시작하지 않습니다. 백업은 완료 표시가 있는 디렉터리만 복원할 수 있으며, 정기적으로 별도 환경에서 복원 시험을 하세요. 복원에 실패하면 백엔드는 중지 상태를 유지합니다. Redis 복원 시 기존 AOF는 데이터 볼륨 안에 `appendonlydir.before-restore-*` 이름으로 보관되므로, 복원 확인 후 디스크 사용량을 점검하세요. 저장소 내부의 `backups/`는 Git에서 제외되지만, 백업은 저장소 밖에 보관하는 것을 권장합니다.

이전 버전의 백업처럼 `postgres.db`와 `mongodb.db`가 없는 백업은 DB 이름을 검증할 수 없어 자동 복원하지 않습니다.

백업 결과물:

| 파일 | 내용 |
|------|------|
| `postgres.dump` | pg_dump 바이너리 포맷 |
| `postgres.db` | 백업 당시 PostgreSQL DB 이름 |
| `mongodb.archive` | mongodump 아카이브 포맷 |
| `mongodb.db` | 백업 당시 MongoDB DB 이름 |
| `redis/appendonlydir/` | Redis AOF 파일과 매니페스트 |
| `backup.complete` | 세 저장소 백업 완료 표시 |

## GitHub 템플릿으로 사용하기

이 저장소를 GitHub Template Repository로 설정하고 새 저장소 생성 후 `bash setup.sh`를 실행하세요. 기능 코드와 환경변수는 새 저장소에서 추가합니다.
