# Decision: I3 — Litestream External Backup

**Date**: 2026-05-14
**Decider**: 자동 추천 적용
**Status**: DEFERRED 30일 — 2026-06-13 재평가
**Related**: 로드맵 I-3 (`docs/superpowers/plans/2026-05-10-post-launch-roadmap.md` § I-3)

## Context

현재 백업 상태 (이미 가동 중):

- `app/services/auction_backup.rb` — 4 DB (production / cache / queue / cable) 로컬 백업
- 보존: 일일 14일 + 주간 28일
- 위치: `/var/backups/auction/{daily,weekly}/YYYYMMDD-HHMMSS/`
- 무결성 체크: 각 백업마다 `PRAGMA integrity_check`
- Kamal 설정 (`config/deploy.yml:87-89`): Docker volume `real_estate_auction_storage:/rails/storage` + 백업 디렉토리 영구 mount

**Risk surface**: 모든 백업이 Cafe24 단일 호스트 디스크에 위치 → 디스크 fail 시 백업 + 원본 동시 손실.

**User stance** (master plan): 외부 사본을 명시적으로 거부 (사유 추정: 데이터 주권 / 한국 외 반출 우려). 운영 1개월 후 재논의 예정.

## Options

| Option | Cost | External data | Restore complexity |
|---|---|---|---|
| **A. 현 상태 유지 (local-only)** | $0 | 없음 | 단순 (디스크 복원만) |
| **B. Litestream → S3** | $1~3/월 (storage) + AWS region 선택 | AWS 에 데이터 | streaming replay 필요 |
| **C. Litestream → 한국 클라우드 (네이버 / KT)** | $2~5/월 | 한국 내 보관 | streaming replay 필요 |

## Decision: A 30일 유지 → 2026-06-13 재평가

### 즉시 강화 (deferred 기간 동안)

- **백업 모니터링** — 마지막 daily 백업 mtime > 24시간 인 경우 알림 (현재 cron 실패 시 무응답)
- **무결성 체크 출력 보존** — `PRAGMA integrity_check` 결과를 backup 폴더 내 `integrity.txt` 로 저장
- **복원 dry-run 1회/월** — `bin/rails db:restore --dry-run` (or 동등) 로 실제로 복원 가능한지 확인

### 30일 후 재평가 항목

- Cafe24 호스트 다운타임/디스크 fail 1건이라도 발생 → C (한국 클라우드) 즉시 도입
- 사용자 데이터가 100건 이상 / 사용자가 본인 외 1인 이상 추가 → 외부 백업 필요성 가중
- 사용자 명시적 입장 변화 → 입장 따라 결정

## Why DEFER vs 즉시 도입

- 현 백업은 **완전히 작동 중**, 무결성 체크 + 14일/28일 retention 으로 hardware 장애 외 모든 시나리오 대응
- Litestream 도입은 **continuous replication daemon 신규 운영** 부담 — Cafe24 4GB RAM 에서 1개 더
- 사용자가 명시적으로 거부한 외부 반출을 우회하는 결정은 신뢰 손상

## Re-evaluation Date

**2026-06-13** (D+30).
