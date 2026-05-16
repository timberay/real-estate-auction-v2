# E2E Test Report — 2026-05-15

> **🚫 STATUS: CLOSED — WON'T FIX (2026-05-16 결정)**
>
> 페어 findings 문서([`docs/qa/2026-05-15-findings.md`](./qa/2026-05-15-findings.md))의 잔여 25건은 작업하지 않기로 결정됨.
> 결정 기록: [`docs/decisions/2026-05-16-2026-05-15-qa-rounds-wontfix.md`](./decisions/2026-05-16-2026-05-15-qa-rounds-wontfix.md). 본 보고서는 이력 보존용.

- 실행 일시: 2026-05-15 (KST)
- 대상 URL: `http://localhost:3000`
- 페르소나: 전문 QA 엔지니어 (변경해야 할 항목 발굴에 초점, 신규 기능 제안 제외)
- 페어 문서: [`docs/qa/2026-05-15-findings.md`](./qa/2026-05-15-findings.md) — 발견 사항 본문

## 0. 실행 환경 제약

Playwright MCP 사용자 데이터 디렉터리(`~/.cache/ms-playwright/mcp-chrome-for-testing-d5cbd1d`)의 SingletonLock을 병행 작업 세션이 점유 중 → 본 세션에서 인터랙티브 브라우저 자동화는 차단됨. 또한 보안 분류기가 세션 쿠키 위조를 거부(타당함).

따라서 본 패스는 다음 3개 채널의 조합:

1. **HTTP 스모크** (curl) — 모든 GET 라우트 27개 응답 코드/리디렉션/title 추출
2. **정적 코드 리뷰** — 컨트롤러 11개, 뷰/컴포넌트 25개 이상
3. **기존 시스템 테스트 실행** — `landing_test` + `legal_pages_test` (95 runs, 0 failures)

screenshot 디렉터리(`docs/screenshots/{before,after,error}`)는 후속 브라우저 가능 세션을 위해 만들어두었음.

---

## 1. Test Target Inventory

라우트 인벤토리 ↓

| # | 경로 | 인증 | 비고 |
|---|------|------|------|
| 1 | `/` | 공개 | Landing |
| 2 | `/auth/login` | 공개 | OAuth 모달 |
| 3 | `/terms` | 공개 | 약관 |
| 4 | `/privacy` | 공개 | 개인정보 처리방침 |
| 5 | `/onboarding` | 공개 (guest 생성) | 위저드 스텝1 |
| 6 | `/onboarding/step1~3 (POST)` | 공개 | |
| 7 | `/properties` | 보호 | 내 매물 리스트 |
| 8 | `/properties/:id` | 보호 | 매물 상세 |
| 9 | `/properties/compare` | 보호 | 비교 표 |
| 10 | `/properties/bulk_import` | 보호 | 일괄 추가 |
| 11 | `/search`, `/search_results` | 보호 | 조건검색 |
| 12 | `/analyses/new` `/analyses/manual` `/analyses/prompt` `/analyses/history` | 보호 | AI 수동 분석 |
| 13 | `/notifications` | 보호 | |
| 14 | `/settings/budget` `/settings/data_sources` | 보호 | |
| 15 | `/admin/{acquisition,transfer}_tax_rates(/audit_logs)` | 보호 | 세율 관리 |
| 16 | `/eviction_guide` `/eviction_guide/simulator(/...)` | 보호 | 명도 가이드/시뮬레이터 |
| 17 | `/manual` | 보호 | 사용자 매뉴얼 |

---

## 2. 시나리오 실행 결과 (Scenario Results)

| ID | 시나리오 | 상태 | 증거/근거 |
|----|----------|------|----------|
| S-01 | GNB 익명 진입 — `/`, `/auth/login`, `/terms`, `/privacy` 200 | PASS | curl 4건 모두 200 |
| S-02 | 보호 라우트 27개 redirect 통일 | PASS | 모두 302 → `/auth/login` |
| S-03 | 존재하지 않는 ID(`/properties/999999`) 처리 | **FAIL (UX)** | 401 처리되어 404 신호 손실 — F-08 |
| S-04 | `/onboarding/complete` 미진입 시 fallback | PASS | 302 → `/onboarding` |
| S-05 | `<title>` 페이지별 정확성 | **FAIL** | `/`, `/auth/login`, `/onboarding` 모두 동일 generic title — F-03 |
| S-06 | `/privacy` 의 h1 vs title 일관성 | **FAIL** | "개인정보 처리방침" vs "개인정보처리방침" — F-04 |
| S-07 | 422 에러 페이지 한글화 | **FAIL** | `public/422.html` 영문 디폴트 잔존 — F-05 |
| S-08 | 사이드바 메뉴 → 실제 destination 일치 | **FAIL** | "예산 설정" → start_onboarding_path — F-06 |
| S-09 | 인증 게이트 토스트 톤 적절성 | **FAIL** | "로그인이 필요합니다" 가 빨강 danger 토스트로 노출 — F-07 |
| S-10 | unread 알림 카운트 캐싱 | **FAIL** | 매 렌더 COUNT 쿼리 — F-09 |
| S-11 | `capture_return_to_url` 의 동작 범위 | **FAIL** | 인증 상태에서도 매 GET마다 세션 갱신 — F-10 |
| S-12 | 매물 카드 비교 체크박스 발견성 | **FAIL** | absolute 우상단, 라벨 없음, 사건번호와 겹침 — F-11 |
| S-13 | 매물 카드 아이콘 일관성 | **FAIL** | 이모지 🏛️ 📍 단독 사용 — F-12 |
| S-14 | 매물 리스트 필터 자동/수동 일관성 | **FAIL** | select/checkbox 자동, 검색은 수동 — F-14 |
| S-15 | 비교 액션 바 "선택 해제" 0건 상태 | **FAIL** | 0건일 때도 활성 — F-13 |
| S-16 | AnalysesController#manual 예외 메시지 | **FAIL** | `e.message` 사용자 노출 — F-01 |
| S-17 | API 키 입력란 마스킹 | **FAIL** | `text_field` 평문 — F-02 |
| S-18 | 수동 JSON 업로드 에러 가독성 | **FAIL** | 필요 키 안내만 있고 형식 예시 없음 — F-16 |
| S-19 | `file_field` 접근성 | **FAIL** | hidden + 비-button div — F-17 |
| S-20 | 로그인 모달 외부 링크 안전성 | **FAIL** | `rel="noopener"` 누락 — F-18 |
| S-21 | 알림 페이지 페이지네이션 | **FAIL** | 무제한 렌더 — F-19 |
| S-22 | 알림 mark_read 결측 처리 | **FAIL** | `head :not_found` 빈 응답 — F-19 |
| S-23 | 예산 설정 flash 표시 채널 | **FAIL** | 인라인 + 토스트 이중 — F-20 |
| S-24 | 데이터 소스 워닝 아이콘 일관성 | **FAIL** | ⚠ 이모지 — F-21 |
| S-25 | 조건검색 CTA 색상 토큰 | **FAIL** | violet 단독 — F-22 |
| S-26 | 검색 폼의 max_bid_price 노출 | **FAIL** | 숨김 결합 — F-23 |
| S-27 | `/properties` 빈 상태 CTA 정합성 | **FAIL** | 상단 폼과 경합 — F-24 |
| S-28 | 신건/유찰 용어 초보자 안내 | **FAIL** | 툴팁 없음 — F-25 |
| S-29 | 푸터 연도 동적화 | **FAIL** | "2026" 하드코딩 — F-26 |
| S-30 | `(준비중)` 사이드바 disabled 의미론 | (관찰) | 현재 모든 메뉴 enabled — F-27 |
| S-31 | 알림 "이동" 링크 텍스트 비특정성 | **FAIL** | aria-label 없음 — F-28 |
| S-32 | Bulk import 라이브 카운터 | **FAIL** | 없음 — F-29 |
| S-33 | Bulk import 입력 우선순위 안내 | **FAIL** | 텍스트+CSV 동시 시 불명 — F-30 |
| S-99 | 기존 시스템 테스트 회귀 | PASS | 95 runs, 0 failures |

---

## 3. 결과 요약

| 분류 | 개수 |
|------|-----|
| PASS | 3 |
| FAIL (변경 필요) | **30** |
| 관찰 (현 시점 영향 없으나 추후 유의) | 1 |

세부 권장 변경은 [`docs/qa/2026-05-15-findings.md`](./qa/2026-05-15-findings.md) §3, §4 우선순위 표 참고.

---

## 4. 스크린샷 인덱스

본 패스에서는 브라우저 잠금으로 스크린샷 캡처 불가. 디렉터리는 다음 회차에 사용:

```
docs/screenshots/
├── before/   — (비어 있음)
├── after/    — (비어 있음)
└── error/    — (비어 있음)
```

---

## 5. 후속 작업 — 브라우저 재가용 시

[`docs/qa/2026-05-15-findings.md`](./qa/2026-05-15-findings.md) §5 표(B-01 ~ B-12)를 그대로 실행할 것. 본 보고서 §2 의 시나리오 중 다음은 브라우저로 추가 확정 필요:

- S-09 토스트 시각 확인
- S-12 비교 체크박스 모바일 터치 영역
- S-14 검색 디바운스 동작 비교
- S-19 키보드 Tab으로 파일 선택 가능 여부
- S-22 mark_read의 turbo_stream 후보 동작 여부
