# UX Audit Remaining Backlog (post-2026-05-10 evening session)

**Source plan:** `docs/superpowers/plans/2026-05-09-ux-audit-fixes-plan.md`
**Audit:** `docs/audits/2026-05-09-ux-audit-beginner.md` + `docs/audits/2026-05-09-ux-audit-expert.md`
**Sessions producing this file:** 2026-05-10 (afternoon ⇒ Phase B Week 2~4: 16/22) + 2026-05-10 (evening ⇒ remaining 6/22 + 2 launch-blocker follow-ups).

## Phase B status — ✅ 22/22 complete

All Phase B exit-criteria items have shipped. Evening-session PRs:

| ID | PR | Title |
|---|---|---|
| B13 | #120 | feat(grade): CSV export of single property analysis report (E-30) |
| B11 | #121 | feat(properties): bulk import 사건번호 paste/CSV with per-row results (E-23) |
| B20 | #122 | feat(analyses): 4-step visual stepper for AI 수동분석 form (B-11) |
| B27 | #123 | feat(rights): inline-edit tenant rows + base_right_date override (E-17) |
| B10 | #124 | feat(properties): per-property notes + 임장 일자 + photo attachments (E-21) |
| B9  | #125 | feat(properties): multi-property compare board with checkbox selection (E-20) |

Plus pre-launch hardening:

| Follow-up | PR | Title |
|---|---|---|
| TZ default Asia/Seoul (#1) + support email (#4) | #119 | chore(config): default time zone to KST + replace placeholder support email |

## Phase C — full backlog (~34 items)

Phase C is post-launch (2026-05-19+) wave 2. Tracked in `2026-05-09-ux-audit-fixes-plan.md` §"Phase C". Sub-buckets:

- **C-1 (모바일/인지/빈 상태, ~22건)** — C1~C20.
- **C-2 (전문가 advanced, ~14건)** — C21~C32. 양도세 매트릭스, 소액임차인 자동계산, DSR, 오피스텔/상가/토지 분기 등.
- **C-3 (Low residual, ~5건)** — C33~C34 + 보강.

Sprint-time task breakdown deferred until sprint start.

## Follow-ups still open (carried over from afternoon session)

Numbering matches the previous backlog version (4 + 1 already shipped via #119).

2. **Other LLM adapters truncation detection** (B30 follow-up) — Gemini/OpenAI/OpenRouter/Ollama 도 max_tokens 잘림 감지 미적용. Anthropic 만 처리됨.
3. **`reserve_fund_default.rb` 영문 validation 메시지** (B21 follow-up) — `errors.add(:area_range_max, "must be greater than area_range_min")` 영문 그대로. admin-only 이지만 일관성 위해 한국어화.
5. **Bid opinion 책임 문구 중복** (B28 follow-up) — `BidOpinionComponent` inline disclaimer + 새 compact LegalDisclaimerComponent 가 한 카드에 연속. 한쪽 정리 권장.
6. **Compact LegalDisclaimerComponent `role="note"`** (B28 follow-up) — 접근성 보강.
7. **Property card overflow menu — Esc/focus management** (B29 follow-up) — WAI-ARIA menu pattern 으로 강화. 다른 카드 메뉴 자동 닫기.
8. **error_message tooltip truncate** (B15 follow-up) — `app/views/analyses/history.html.erb` 의 `title` 속성 도 `truncate(..., length: 500)` 적용해 DOM 노출 표면 축소.
9. **InspectionResultVersion 동시성** (B26 follow-up) — `versions.maximum(:version_number).to_i + 1` race 가능. 이중 클릭 시 `RecordNotUnique` 발생할 수 있음. `rescue + retry` 또는 advisory lock.
10. **InspectionResultVersion snapshot 추가 SELECT** (B26 follow-up) — `InspectionResult.find(result.id)` 추가 쿼리 발생. dirty tracking (`*_was`) 활용으로 줄일 수 있음.
11. **Heading hierarchy on property/show inlined manual form** (B14 follow-up) — `_manual_form` 의 `<h2>` 가 property/show 의 `<h3>` 아래에 위치. `heading_level:` 로컬 추가 검토. (B20 PR #122 이후 stepper 컴포넌트가 `<h*>` 를 안 쓰므로 부분적으로 해결됐음 — 재확인 필요.)
12. **Triple-nested cards on property/show manual form** (B14 follow-up) — `/design-review` 한 번 권장. (B20 stepper 도입 후 카드 구조가 바뀌어 원인 변경됐을 수 있음 — 재확인 필요.)

## Follow-ups discovered in 2026-05-10 evening session

13. **AI 재분석이 사용자 편집 임차인을 silently 덮어쓴다** (B27 PR #123 follow-up) — `report_data` 가 통째로 교체되므로 `tenants[*]["user_edited"] = true` 플래그가 무시됨. 옵션: (a) 재분석 진입 전 confirm UI, (b) merge 로직 (user_edited 행은 보존), (c) 재분석 직후 diff 화면. 베테랑 retention 측면에서 (a) 가 빠른 안전망.

14. **B27 Cancel 버튼 — 재택 시 base_right_date show 액션 테스트 누락** — `RightsAnalysisReportsController#show_base_right_date` 신규 추가됐으나 controller test 미작성. PR #123 머지 전 catch 못함.

15. **B27 입력 검증 — invalid deposit 시 500 가능** — `Integer(attrs[:deposit])` 가 `ArgumentError` 시 `update` 액션에 rescue 없음. browser `<input type="number">` 가 막아주지만 API/직접 form post 시 500. `tenant_params` 단계에서 rescue → 422 권장.

16. **B27 임차인 날짜 비울 수 없음** — `attrs[:confirmed_date].presence || tenants[index]["confirmed_date"]` 패턴이 사용자가 의도적으로 빈 값 저장을 막음. nil/빈 문자열 명시적 클리어 허용 검토.

17. **B10 사진 N+1** — `_photos.html.erb` 가 `url_for(photo)` 매번 호출, blob 쿼리 N건. 1~10건 범위에서 무시 가능하나 `with_attached_photos` preload 검토.

18. **B10 멀티파일 업로드** — `<input type="file">` 에 `multiple: true` 미설정. UX 개선으로 추가 검토.

19. **B10 update! rescue 없음** — `UserPropertySettingsController#update` 가 `update!` 사용 + `rescue ActiveRecord::RecordInvalid` 없음. 현재 notes/date 모델 검증이 없으므로 fail 안 나지만 방어적 보강 권장.

20. **B9 CSV export of comparison** — 현재 단일 물건 CSV (B13 #120) 만 존재. 비교 페이지에서 N건 한꺼번에 CSV 받는 옵션이 베테랑 워크플로우에 유용.

21. **B9 예상순이익 column** — 비교 테이블에 추가 검토. 입찰가 입력값 per-property 가 필요해 별도 modal 또는 컬럼 인라인 input 설계 필요.

22. **B9 Sortable columns** — read-only v1. 정렬 토글 추가 검토.

23. **B9 sessionStorage 영속 테스트** — 새로고침 후 체크 상태 유지 시스템 테스트 누락. 동작은 구현됐으나 회귀 가드 부재.

24. **B11 bulk import 50+ rows synchronous 25s 블로킹** — Cafe24 4GB single-server, Puma worker 한정. N>10 시 background job 검토.

## Operational notes (carryover)

- 모든 Phase B PR 은 automerge 라벨 적용. 본 세션 #125 (B9) 머지 시점에서 Phase B 22건 100% 완결.
- 본 세션 신규 follow-up 12건 (#13~#24) 은 모두 출시 후 처리 가능 (Critical 없음, 보안 영향 없음).

---

**End of backlog (post 2026-05-10 evening session).**
