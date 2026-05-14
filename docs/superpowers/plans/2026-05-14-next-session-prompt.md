# 다음 세션 시작 프롬프트 (T4 진행 — 잔여 3건)

**작성일**: 2026-05-14
**용도**: 다음 Claude Code 세션에 이 파일 내용을 그대로 paste 해서 T4 자동 진행 모드 진입.

---

## 다음 세션에 paste 할 내용

```text
다음 지침을 기준으로 real-estate-auction 프로젝트의 Theme 4 잔여 작업을 진행해줘.

## 이전 세션 (2026-05-14) 결과

Theme 4: 6/9 완료. 머지된 PR 6건:
- T4.1 PR #157 — 모바일 정렬 (C2/C3/C7/C13/C17, C1 은 PR #118 에서 이미 처리됨)
- T4.2 PR #158 — 내부 코드 노출 제거 (C4/C5/C20)
- T4.3 PR #159 — 인지 흐름 정리 (C6/C9/C15/C18, C10 은 controller redirect 으로 이미 처리됨)
- T4.4 PR #160 — 안내/가이드 CTA (C8/C14/C16/C19)
- T4.5 PR #162 — 모바일 tooltip 클릭 토글 (C12; C11 은 controller redirect 와 mismatch 로 SKIP)
- T4.7 PR #161 — analyses#prompt rate-limit (C31/E-39)

마스터 TODO 진실 소스: `docs/superpowers/plans/2026-05-14-master-todo.md`
원본 reference: `docs/superpowers/plans/2026-05-10-post-launch-roadmap.md`

## 작업 패턴 (이전 세션에서 검증됨)

1. 마스터 TODO 가 진실 소스. 새 작업 시작/완료 시마다 업데이트 + commit + push.
2. 의사결정 알아서 추천 방향. 기능 대폭 추가 피한다 — minimum viable 로 좁히고 follow-up 분리.
3. 단일 PR per task. 작업 끝나면 한 번에 PR.
4. Telegram 핑 (chat_id 8539138772) — 자주:
   - 시작 시 스코프 결정 공유
   - 마일스톤마다 짧게 ("검사 통과" 표현 사용)
   - 의미있는 상태 전이마다 (RED→GREEN, 풀 스위트 결과, PR 생성, 라벨 추가, 머지)
   - 결정 필요 시 Telegram 질문 + 시간 내 응답 없으면 추천대로 진행
   - 완료 시 PR 번호 + 다음 후보
5. 각 소기능 완료 전 충분한 검사 — TaskUpdate(completed) 전 반드시 통과:
   단위 → 시스템 → 전체 스위트 → 실 브라우저 QA (정상/경계/에러) → 콘솔/서버 로그 → 발견된 모든 오류 수정 → 재검사 루프.
6. TDD + Tidy First. pre-commit hook 이 풀 스위트를 돌리므로 작은 변경도 모두 통과 후에만 commit.
7. /push2gh 스킬 — Flow C: feature branch + PR + automerge 라벨 + gh pr merge 번호 --squash --delete-branch. 머지 후 main 동기화 + 마스터 TODO 업데이트 commit + push.
8. 중지("중지") 요청 시 즉시 정지, 상태 보고.
9. 실 브라우저 QA 시 `RAILS_ENV=development bundle exec rails server -d` 로 daemonized 시작 (background bash 는 harness 가 SIGTERM 보냄). 종료는 `cat tmp/pids/server.pid | xargs kill`.
10. tooltip toggle 같은 Stimulus interaction 은 system test 로 회귀 가드 (browser QA 는 자동화 보충용).

## 잔여 Theme 4 항목 (3건)

| ID | 항목 | 상태 / 결정 필요 |
|----|------|----------------|
| T4.6 | a11y 점검 패스 (axe-core 통합) | 인프라 + 발견될 issue 별도 PR. 진행 의향 확인 필요. |
| T4.8 | Backlog P3 묶음 8건 (한국어화 / disclaimer / menu Esc / tooltip / heading / nested cards / base_right_date 컨트롤러 테스트) | 잡다 — 작은 묶음으로 쪼개기. |
| T4.9 | 외부 게이트 5건 — CSP enforce 플립, OAuth 콘솔 redirect URI, SNS self-review (multi-tab/account settings/rack-attack/terms·privacy), OAuth Symbol provider 회귀 테스트, branch protection 정책 결정 | 사용자 결정 필요 (OAuth/CSP/도메인). |

### T4.8 세부 (Follow-up 8건)
- #3 `reserve_fund_default.rb` 영문 validation 한국어화 (admin-only)
- #5 Bid opinion 책임 문구 정리
- #6 LegalDisclaimerComponent role="note"
- #7 Property card overflow menu Esc/focus management (WAI-ARIA menu)
- #8 error_message tooltip truncate
- #11 property/show heading hierarchy
- #12 property/show nested cards
- #14 B27 base_right_date show 액션 controller test

원본 본문은 `docs/superpowers/plans/2026-05-10-ux-audit-remaining-backlog.md` 의 "Follow-ups discovered" 절.

### T4.9 세부
- W0-1 CSP report_only → enforce (1주 csp.violation 0건 확인 후 플립)
- W0-2 OAuth 콘솔 redirect URI (Google/Naver/Kakao, 운영 도메인 확정 후)
- W0-3 SNS self-review 4건 — multi-tab session sync, account settings, rack-attack 확장, /terms /privacy 본문
- W0-4 OAuth Symbol provider 회귀 테스트 (test/infra debt)
- W0-5 Branch protection 정책 — GitHub Pro 구독 / public 전환 / status check polling

원본은 `docs/superpowers/plans/2026-05-10-post-launch-roadmap.md` 의 Wave 0 절.

## 다음 작업 추천 우선순위

1. **T4.8 의 작은 묶음 먼저** — minimum viable, decision 불필요.
   - 첫 묶음 추천: #3 한국어화 + #6 role="note" + #14 controller test (가장 단순한 3건).
   - 둘째 묶음: #5 disclaimer + #8 tooltip truncate.
   - 셋째 묶음: #7 a11y menu + #11/#12 heading/cards (a11y 인접).

2. **T4.6 axe-core 인프라** — 인프라 도입 의향이 있으면 진행.
   - minimum viable: `axe-core-capybara` gem (or vendor axe.min.js) + ApplicationSystemTestCase 의 helper + 핵심 페이지 1~2개 baseline assertion. 발견될 a11y 이슈는 별도 PR.

3. **T4.9 외부 게이트** — 사용자 결정 후 진행. 
   - 가장 작음: W0-4 OAuth Symbol provider 회귀 테스트 (test 추가만).
   - 다음 작음: W0-1 CSP enforce 플립 (1주 운영 로그 확인 후).
   - 큰 결정: W0-2 redirect URI (운영 도메인 확정 필요), W0-3 self-review 4건, W0-5 branch protection 정책.

## 시작 명령

마스터 TODO + roadmap + remaining-backlog 문서를 훑은 뒤 위 우선순위 1번 (T4.8 첫 묶음 #3+#6+#14) 부터 위 패턴 그대로 진행해줘. 다른 흐름이 더 적합해 보이면 Telegram 추천 후 진행.

## 메모리

`~/.claude/projects/-home-tonny-projects-real-estate-auction/memory/`
- `feedback_thorough_qa.md` — 검사 통과 표현 + 충분한 검사 루프
- `feedback_telegram_milestone_pings.md` — 자주 핑
- `feedback_no_launch_schedule.md` — 일정 추적 X, 기능만

이대로 다음 세션에 붙여 넣으면 T4 잔여 자동 진행 모드 (자율 의사결정 + minimum viable + 단일 PR + Telegram milestone ping) 로 진입.
```

---

## 이번 세션 마무리 노트

- Theme 4 진행: 6/9 (T4.1·T4.2·T4.3·T4.4·T4.5·T4.7)
- 머지된 PR: #157, #158, #159, #160, #161, #162
- 풀 unit 1636+ runs / system 85 runs / 모두 통과
- 발견된 부가 이슈:
  - `ButtonComponent.new(...) { "text" }` block syntax 가 Class.new 에 binding 되어 텍스트 잃음. `do/end` 로 회피 (PR #159 complete.html.erb)
- 잔여: T4.6 (a11y 인프라), T4.8 (P3 8건), T4.9 (외부 게이트 5건)
