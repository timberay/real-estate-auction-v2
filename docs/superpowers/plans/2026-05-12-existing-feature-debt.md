# 기존 기능 부채 감사 (2026-05-12 기준)

**작성일**: 2026-05-12 (출시 D-7)
**범위**: 새 기능 구현이 아닌, 이미 출하된 기능에 묻혀 있는 결함/부채.
**방법**: 전체 코드베이스 grep + schema 검토 + PR 리뷰 backlog 통합.
**관련 문서**:
- `TODOS.md` (2026-05-04, 사건번호 후속 3건)
- `docs/superpowers/plans/2026-05-10-post-launch-roadmap.md` (Wave 1-4 + 22 follow-ups)
- `docs/superpowers/plans/2026-05-10-ux-audit-remaining-backlog.md` (PR #107~#125 follow-up 22건)
- `docs/superpowers/plans/2026-04-22-oauth-hardening.md` (OAuth Phase 4/5)

---

## A. 시스템적 결함 — 다수 위치에 반복 (높음)

### A1. 컨트롤러 `update!`/`save!`/`create!` rescue 누락 — 19개소

`ActiveRecord::RecordInvalid` 발생 시 500 응답. browser HTML form 은 client-side validation 으로 막아주지만 API 직접 호출 / form 우회 / 동시 편집 시 5xx 노출.

대표 위치:
- `properties_controller.rb:65,75` (`destroy!`, `update!`)
- `search_results_controller.rb:91,103,107` (case-number 등록 경로)
- `inspections/tabs_controller.rb:53,109,126` (모든 tab update)
- `inspections/resolutions_controller.rb:46,53`
- `properties/user_property_settings_controller.rb:11` (backlog #19 이미 식별)
- `properties/rights_analysis_reports_controller.rb:22` (backlog #15 이미 식별)
- `eviction_guide/simulations_controller.rb:19,51,60,77` (4건)
- `users_controller.rb:3` (toggle beginner_mode)
- `settings/api_credentials_controller.rb:22`

**해결**: 모델 단계 validation 보강 + 컨트롤러에 `rescue ActiveRecord::RecordInvalid` → 422 + 한국어 메시지 일관 처리. **systemic fix** 권장 (`Controllers::ErrorRescue` concern 또는 `application_controller.rb` 의 `rescue_from`).

### A2. LLM adapter 잘림(truncation) 감지 비일관

| adapter | finish_reason / MAX_TOKENS 처리 |
|---------|-----------------------------|
| anthropic | ✅ 6회 매치 (B30 PR #118) |
| open_ai | ⚠️ 2회 (부분) |
| open_router | ⚠️ 2회 (부분) |
| **gemini** | ❌ 0회 |
| **ollama** | ❌ 0회 |

backlog #2 는 "Anthropic 외 모두 누락"이라 적혀 있는데 실제로는 OpenAI/OpenRouter 도 일부 처리됨 — 정확한 진단을 다시 작성해야 함. **Gemini/Ollama 우선 처리** + 공통 `LlmTruncationError` interface 통일.

### A3. JS/Stimulus 테스트 0건

- `app/javascript/controllers/` 에 35개 컨트롤러 (analysis_form, criteria_search, profit_calculator, simulator, property_compare 등 핵심 인터랙션)
- `test/javascript/` **디렉토리 없음**
- `test/system/` 24개 — 실제 브라우저 동작은 일부 확인되지만 컨트롤러 단위 로직(`profit_calculator_controller.js:32-43` 세율 매트릭스 등) 회귀 가드 없음

**해결**: Vitest/Jest 도입 검토. 또는 핵심 계산 로직(profit_calculator)만이라도 system test 비중 보강.

### A4. PDF/LLM 파이프라인의 광범위 `rescue => e` — 8개소

위치: `pdf_analysis_service.rb:32,237,281`, `pdf_analysis_job.rb:101,128,143,154`, `analyses_controller.rb:69`

외부 API 호출의 unknown failure 흡수는 정당하나, **모두 같은 `e`를 잡고 같은 로그 포맷**으로 처리 — 일부는 retry-able, 일부는 fatal 인데 구분 안 됨. PR #105 (PdfAnalysisJob retry/discard 분리) 가 시작됐지만 service-layer 까지 확산 미적용.

---

## B. 출시 차단/근접 (중간) — 노트북 목록 + 새 로드맵에서 모두 누락된 항목

### B1. CSP 시행 모드 전환 (OAuth Hardening Phase 5)

- 현재: `config/initializers/content_security_policy.rb:25` → `report_only = true`
- 계획: `2026-04-22-oauth-hardening.md` 에 명시. 운영 1주 후 `csp.violation` 로그 0건 확인 → `false` 플립
- **새 post-launch roadmap 에 누락**

### B2. OAuth 콘솔 redirect URI 등록 (Google/Naver/Kakao)

- 운영 도메인 확정 후 console 설정 필요. 코드 변경 없음, 외부 작업.
- **두 목록 모두 명시 안 됨 또는 stale**

### B3. SNS 로그인 self-review 4건

- Multi-tab session sync (Turbo Cable)
- Account settings 페이지 (provider 연결/데이터 내보내기)
- rack-attack 확장 (progressive backoff, denylist)
- `/terms` `/privacy` 본문 작성 ← 출시 전 법적 요구 가능성

### B4. OAuth Symbol provider 회귀 테스트 (test/infra debt)

노트북 메모 항목. 새 로드맵에 없음.

### B5. Branch protection 정책 — GitHub Pro 미구독

노트북 메모대로 main 보호 불가. 옵션: Pro 구독 / public 전환 / status check polling. 출시 후 재평가 필요.

---

## C. 코드 내 명시적 부채 (낮음 ~ 중간)

### C1. `preferred_purchase_risk` 라벨 의미 충돌 — A6 follow-up

- `app/components/rights_report_section_component.html.erb:14` 에 명시적 TODO 코멘트
- "opportunity" 섹션에 렌더링되지만 의미는 risk signal — 사용자 오해 위험
- LLM 프롬프트(`pdf_prompt_builder.rb:48,52,114`) 와 컴포넌트 라벨 모두 정합 필요

### C2. `TODOS.md` 사건번호 후속 3건 (이미 알려짐, 재게재)

- 60-법원 auto-discovery fallback (ActiveJob 필요)
- `Property#refresh_from_court_auction!`
- CaseSearchService race-rescue 테스트 (`case_search_service.rb:39-40` dead branch)

### C3. `Gemfile` 의 `:windows` 플랫폼 심볼

- `Gemfile:37: gem "tzinfo-data", platforms: %i[ windows jruby ]`
- Ruby 3.0.0 + 구 Bundler 환경에서 파싱 실패. 운영/CI 가 Ruby 3.1+ 이면 무해하지만 **dev 환경 표준화 깨짐** — `.ruby-version` 확정 + Bundler 버전 명시 필요

---

## D. 이미 backlog 에 정리된 22건 (재확인용 압축)

원문은 `docs/superpowers/plans/2026-05-10-ux-audit-remaining-backlog.md`.

**P1 (출시 후 1주)**: #2 LLM adapter truncation (A2 와 통합), #13 AI 재분석 silent overwrite

**P2 (출시 후 2~3주)**:
- #9 InspectionResultVersion race (이중 클릭 RecordNotUnique)
- #10 InspectionResultVersion 추가 SELECT (dirty tracking 활용)
- #15 B27 invalid deposit → 500 (A1 의 인스턴스)
- #16 B27 임차인 날짜 빈 값 저장 불가
- #17 B10 사진 N+1 (`with_attached_photos`)
- #18 B10 멀티파일 업로드 (`multiple: true`)
- #19 B10 update! rescue (A1 의 인스턴스)
- #20 B9 비교 CSV export
- #21 B9 예상순이익 column
- #22 B9 sortable columns
- #23 B9 sessionStorage 영속 시스템 테스트
- #24 B11 50건 25s 블로킹 → background job

**P3 (출시 후 1개월+)**:
- #3 `reserve_fund_default.rb` 영문 validation 메시지 한국어화
- #5 Bid opinion 책임 문구 중복
- #6 LegalDisclaimerComponent `role="note"`
- #7 Property card overflow menu Esc/focus management (WAI-ARIA)
- #8 error_message tooltip truncate
- #11 property/show heading hierarchy 재확인
- #12 property/show 삼중 nested cards 재확인
- #14 B27 base_right_date show 액션 controller test

---

## E. 통합 권장 (메타)

현재 to-do 가 3곳에 분산:
1. `TODOS.md` (3건, 2026-05-04)
2. `docs/superpowers/plans/2026-05-10-post-launch-roadmap.md` (Wave 1-4 + follow-ups)
3. 노트북에 남은 OAuth/SNS 컨텍스트 (디스크에 없음)

→ **`TODOS.md` 폐기 또는 단일 통합** 권장:
- Option A: `TODOS.md` 를 인덱스로 두고 carve-outs 만 명시, 본문은 roadmap 으로 링크
- Option B: roadmap 안으로 모두 흡수 (Wave 0 "Deploy-gated" 신설 — OAuth Phase 5 / 콘솔 URI / SNS self-review 등)

---

## 검토 범위 / 한계

**스캔 완료**:
- 전체 컨트롤러/서비스/어댑터 bang-method, rescue 패턴
- DB schema FK + 인덱스 (`db/schema.rb`)
- LLM adapter 5개 truncation handling
- 모델 validation 누락
- 코드 내 TODO/FIXME/HACK 마커
- Stimulus 컨트롤러 vs 테스트 매핑
- TZ-unsafe time 호출 (없음 — Phase A 가 깨끗하게 처리)

**미스캔 (별도 세션 권장)**:
- `/cso` 또는 `/security-review` 실행 — secret scan, OWASP, supply chain
- N+1 정밀 분석 (bullet gem 도입 + 실측)
- Rubocop 전체 실행 (Bundler 환경 이슈로 본 세션에서 실패)
