# UX Audit Remaining Backlog (post-2026-05-10 session)

**Source plan:** `docs/superpowers/plans/2026-05-09-ux-audit-fixes-plan.md`
**Audit:** `docs/audits/2026-05-09-ux-audit-beginner.md` + `docs/audits/2026-05-09-ux-audit-expert.md`
**Session that produced this file:** 2026-05-10. 12 PRs (#107, #108, #110–#118) shipped 16 individual audit items from Phase B Week 2~4. PR #109 (B26) was rebased and is merge-pending; PRs #114 (B28) and #115 (B29) are awaiting CI / merge.

## Phase B remaining (6 items)

| ID | Audit Ref | Task | Files (plan-suggested) | Effort | Why deferred |
|---|---|---|---|---|---|
| B9  | E-20 | 다물건 비교 보드 (체크박스 N건 → 비교 테이블 모달) | `app/views/properties/compare.html.erb` (new), controller action | L (10h) | 새 view + controller + select-state Stimulus + test 분량이 큼; 단일 세션에 무리 |
| B10 | E-21 | UserProperty 메모/사진/임장노트 | migration, `user_properties_controller`, view | L (8h) | 마이그레이션 + ActiveStorage + 새 컨트롤러 + 시스템 테스트 |
| B11 | E-23 | bulk import (CSV/줄바꿈 paste) | `properties/bulk_import_controller`, service | M (5h) | 사건번호 파싱 service + 부분 실패 처리 + 신규 UI |
| B13 | E-30 | CSV/Excel export | `app/services/export/inspection_csv_exporter.rb` (new) | M (4h) | 새 서비스 + 컨트롤러 + 권한 점검 |
| B20 | B-11 | AI 수동분석 4단계 스텝퍼 + 스크린샷 | `analyses/_manual_form.html.erb` | M (4h) | manual_form 이 이미 property show 에도 embedded 됨 (B14 PR #110) — 스텝퍼 UI 재설계 시 양쪽 surface 모두 고려 필요 |
| B27 | E-17 | 임차인 inline edit | `tenants_controller` (new), turbo frames | M (5h) | 새 컨트롤러 + Turbo Frame 라우팅 + RightsAnalysisReport 와의 데이터 흐름 |

**Subtotal:** 36h (L: 18h, M: 18h)

## Phase C — full backlog (~34 items)

Phase C는 출시 후(2026-05-19+) wave 2 로 이미 plan 에 표 형태로 정리됨. 본 세션에서 다음 사항만 명시:

- **C-1 (모바일/인지/빈 상태, ~22건)** — `2026-05-09-ux-audit-fixes-plan.md` §"Phase C — C-1" 표 그대로 유지. C1~C20.
- **C-2 (전문가 advanced, ~14건)** — C21~C32. 양도세 매트릭스, 소액임차인 자동계산, DSR, 오피스텔/상가/토지 분기 등.
- **C-3 (Low residual, ~5건)** — C33~C34 + 보강.

Phase C 항목들의 sprint 시점 task breakdown 은 sprint 시작할 때 확장.

## Follow-ups discovered in 2026-05-10 session (track separately)

다음 항목들은 본 세션 PR 들에서 review 가 잡아낸 nit/follow-up:

1. **TZ default to "Asia/Seoul"** (B12 follow-up) — `config/application.rb` 의 `time_zone` 미설정으로 UTC 사용 중. D-day 계산 한국 사용자 기준으로 정확하지 않을 수 있음. 별도 PR 권장.
2. **Other LLM adapters truncation detection** (B30 follow-up) — Gemini/OpenAI/OpenRouter/Ollama 도 max_tokens 잘림 감지 미적용. Anthropic 만 처리됨.
3. **`reserve_fund_default.rb` 영문 validation 메시지** (B21 follow-up) — `errors.add(:area_range_max, "must be greater than area_range_min")` 영문 그대로. admin-only 이지만 일관성 위해 한국어화.
4. **Support email placeholder** (B21 follow-up) — `app/views/shared/error.html.erb` 의 `support@example.com` 을 실제 ops 주소로 교체 필요. 출시 전 차단성 항목.
5. **Bid opinion 책임 문구 중복** (B28 follow-up) — `BidOpinionComponent` inline disclaimer + 새 compact LegalDisclaimerComponent 가 한 카드에 연속. 한쪽 정리 권장.
6. **Compact LegalDisclaimerComponent `role="note"`** (B28 follow-up) — 접근성 보강.
7. **Property card overflow menu — Esc/focus management** (B29 follow-up) — WAI-ARIA menu pattern 으로 강화. 다른 카드 메뉴 자동 닫기.
8. **error_message tooltip truncate** (B15 follow-up) — `app/views/analyses/history.html.erb` 의 `title` 속성 도 `truncate(..., length: 500)` 적용해 DOM 노출 표면 축소.
9. **InspectionResultVersion 동시성** (B26 follow-up) — `versions.maximum(:version_number).to_i + 1` race 가능. 이중 클릭 시 `RecordNotUnique` 발생할 수 있음. `rescue + retry` 또는 advisory lock.
10. **InspectionResultVersion snapshot 추가 SELECT** (B26 follow-up) — `InspectionResult.find(result.id)` 추가 쿼리 발생. dirty tracking (`*_was`) 활용으로 줄일 수 있음.
11. **Heading hierarchy on property/show inlined manual form** (B14 follow-up) — `_manual_form` 의 `<h2>` 가 property/show 의 `<h3>` 아래에 위치. `heading_level:` 로컬 추가 검토.
12. **Triple-nested cards on property/show manual form** (B14 follow-up) — `/design-review` 한 번 권장.

## Operational notes

- Phase B 22건 중 16건 본 세션 처리, 6건 backlog. exit criteria ("All 30 tasks merged") 미달이지만 Critical/High 핵심 spec 은 거의 이행. Veteran-axis 의 워크플로 기능(B9 비교, B10 메모, B11 bulk, B13 export, B27 임차인 편집)이 나머지 6건의 핵심 — 출시 후 retention 측면에서 우선 복구 권장.
- B20 4단계 스텝퍼는 manual_form 이 이미 두 surface 에서 사용되므로 (property/show inlined + /analyses/new) 디자인 변경 시 양쪽 동기화 필요.
- 본 세션 모든 PR 은 automerge 라벨 적용. 일부(#109 B26, #114 B28, #115 B29) 는 본 보고 시점 CI 진행/대기 중.

---

**End of backlog.**
