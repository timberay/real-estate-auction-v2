# Deferred Features (2026-05-14)

본 문서는 이번 정리 세션 (2026-05-14) 에서 의도적으로 deferred 한 항목들을 모아 둠.
각 항목은 실현 가치가 있으나 (a) 별도 product 결정이 필요하거나 (b) 큰 기능이라 별도 세션이
적합한 경우.

## D3a — Courts 60-법원 Auto-Discovery + ActiveJob

**Source**: `docs/superpowers/plans/2026-05-12-existing-feature-debt.md` § C2

**Why deferred**: 환경 부채가 아니라 **신규 기능**. 60개 법원 iteration 은 단순 loop 이지만:

- ActiveJob (Solid Queue) 인프라 의존
- Per-court rate limit 고려 (현재 `COURT_AUCTION_MIN_REQUEST_INTERVAL=0.5`)
- 부분 결과 / 진행 상태 사용자 노출 UX (60건 순회는 30~60초)
- 실패 코트 retry 정책

**Re-trigger**: 사용자가 court_code 모르고 case_number 만 입력하는 use case 가 실제로 발생할 때.
현재는 사용자가 court_code 직접 선택 → 즉시 결과를 받는 flow 가 우선.

## W0-3.1 — Multi-tab Session Sync (Turbo Cable)

**Source**: 로드맵 W0-3 sub-item 1

**Why deferred**: **product 결정 필요**.

- 1탭에서 로그아웃 시 다른 탭들의 동기화 시점 (즉시 / next request)
- 1탭에서 budget 변경 시 다른 탭의 budget indicator 갱신
- Turbo Cable broadcast channel 설계 + Stimulus 리스너 패턴
- 동시 편집 conflict 시나리오 (eviction simulation 동시 수정)

이 모두가 단순 "로그아웃 broadcast" 보다 큰 product 결정. 사용자 본인이 multi-tab 사용 패턴이
실제로 friction 으로 느껴질 때 진행.

**Re-trigger**: 사용자 보고 또는 자기 dogfood 에서 "다른 탭이 stale" 시나리오 1건 이상.

## W0-3.2 — Account Settings (OAuth Provider Mgmt + Data Export)

**Source**: 로드맵 W0-3 sub-item 2

**Why deferred**: **신규 기능**, GDPR/PIPA 요구 시점에 도입.

- OAuth provider 연결/해제 UI (Identity model 기반 — 다중 OAuth 계정 연결 시나리오)
- 사용자 데이터 export (CSV) — properties / inspections / rights_analysis_reports / eviction_simulations
- 회원 탈퇴 + 데이터 파기 flow
- 개인정보 열람/정정 요청 처리

W0-3.4 (terms/privacy) 의 PIPA 준수 요구와 묶어 한 PR 로 진행하는 것이 일관됨.

**Re-trigger**: W0-3.4 법무 검토 결과 회원 탈퇴 / 데이터 export 가 명시적으로 요구될 때
(통상 한국 PIPA 표준 약관 포함).
