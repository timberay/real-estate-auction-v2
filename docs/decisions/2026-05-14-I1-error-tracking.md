# Decision: I1 — Error Tracking (GlitchTip vs Sentry vs lograge-only)

**Date**: 2026-05-14
**Decider**: 자동 추천 적용
**Status**: DEFERRED 1주 — 운영 1주 lograge 관찰 후 재결정
**Related**: 로드맵 I-1 (`docs/superpowers/plans/2026-05-10-post-launch-roadmap.md` § I-1)

## Context

T2.1 lograge 구조화 로깅 (#144) 완료 — 1요청 1JSON, production+test 활성, custom payload
(request_id, remote_ip, user_id, guest, exception). 현재 Gemfile 에 `sentry-ruby` /
`glitchtip-ruby` 같은 외부 에러 트래커 없음.

## Options

| Option | Setup cost | Run cost | Operational overhead |
|---|---|---|---|
| **A. lograge-only** | 0 | 0 (이미 가동) | jq + grep 으로 운영 (현재 상태) |
| **B. Sentry free tier** | 30분 (gem 추가 + DSN 등록) | $0 (5K events/월 무료) | 거의 없음 (SaaS) |
| **C. GlitchTip self-hosted** | 2~3시간 (Docker + Postgres + Cafe24 디스크 4GB 고려) | 서버 자원만 | 중간 (Docker 컨테이너 + DB 운영) |

## Decision: DEFER 1주 → 그 후 옵션 B (Sentry) 권장 if 필요

### 1주 관찰 항목

- lograge 로그에서 exception payload 가 실제 디버깅에 충분한지 (stack trace 포함, request_id 추적 가능)
- 일일 grep/jq 빈도가 5회 초과하는지 (하루 5회 넘으면 search/aggregate 인터페이스가 필요한 신호)
- 5xx 응답률이 0.1% 초과하는지 (운영 신호)

### 결정 가이드

| 1주 관찰 결과 | 권장 |
|---|---|
| exception 빈도 낮음 (<5건/일) + grep 충분 | A 유지 |
| exception 빈도 보통 + 검색/집계 needed | B Sentry free tier 도입 |
| exception 빈도 높음 + 데이터 외부 반출 정책상 불가 | C GlitchTip 도입 (Cafe24 메모리 여유 확인 필수) |

### 자동 추천 근거 (Sentry over GlitchTip)

- Sentry free tier 5K events/월 = 본 프로젝트 출시 직후 트래픽 규모에 충분
- self-hosted overhead 가 정당화되려면 데이터 외부 반출 거부가 명확해야 함 (현재 그런 정책 없음)
- Cafe24 4GB RAM 제약상 Sentry SaaS 가 운영 부담 측면에서 우월

## Re-evaluation Date

**2026-05-21** (D+7).
