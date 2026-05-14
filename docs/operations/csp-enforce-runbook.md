# Runbook: W0-1 — CSP Enforce Mode 전환

**Date**: 2026-05-14
**Status**: 코드 준비 완료, **운영 1주 무위반 관찰 후 실행**
**Related**: 로드맵 W0-1 (`docs/superpowers/plans/2026-05-10-post-launch-roadmap.md` § W0-1)
**Code change**: 1줄 (`config/initializers/content_security_policy.rb:25`)

## What this runbook does

`content_security_policy_report_only = true` → `false` 로 플립.
CSP 정책 위반 시 브라우저가 **차단**(현재는 로깅만).

## Pre-flight checklist

다음을 모두 만족하는 경우에만 실행:

- [ ] **운영 7일 연속** `csp.violation` 로그 0건 (브라우저 확장 source schema 제외 — `chrome-extension://`, `moz-extension://`, `safari-extension://` 등은 무시)
- [ ] OAuth 3개 provider (Google / Naver / Kakao) 콜백 round-trip 정상 (form_action allowlist 가 모두 포함되었는지 재확인)
- [ ] 외부 폰트 / CDN 리소스 사용 없음 (현재 Tailwind/Heroicon 모두 self-served — 검증)
- [ ] inline `<script>` 사용 없음 (nonce 기반 javascript_tag 만 사용 중 — 검증)

## Execution

### Step 1: 코드 변경

```ruby
# config/initializers/content_security_policy.rb:25
config.content_security_policy_report_only = false  # was: true
```

### Step 2: 배포 + 5분 모니터링

```bash
bin/kamal deploy
# 5분 동안 production logs 에서 다음 패턴 감시:
# - "Content Security Policy" 위반
# - 5xx 응답
# - OAuth 콜백 실패
```

### Step 3: 사용자 영향 확인 (자기 점검)

- [ ] /auth/login 진입 → 3개 OAuth provider 모두 클릭 가능
- [ ] /properties → 카드 정상 렌더링 (이미지, JS interactions)
- [ ] /properties/:id → AI 분석 탭 전환, profit_calculator 동작
- [ ] /settings/budget → 슬라이더 실시간 반영

## Rollback

위반 발생 시 즉시 revert:

```bash
git revert <commit-sha>
bin/kamal deploy
```

복구 시간 < 3분 예상.

## Post-flip monitoring

배포 후 24시간 동안 다음 알림:

- CSP 위반 로그 발생 즉시 Telegram/Slack 알림
- 5xx 응답률 0.5% 초과 시 알림

## Why DEFER until 1-week observation

CSP 정책은 **client-side 차단**. 누락된 source 가 있으면 사용자 화면이 깨지지만 서버 로그에 명확히 안 잡힐 수 있음.
1주 관찰 기간 동안 다양한 사용 패턴 (OAuth 3개 provider, AI 분석, profit_calculator, sidebar 등)이 한 번씩
실행되도록 하여 위반 source 를 모두 발굴하는 것이 안전.

## Owner

코드 변경: 1인. 모니터링: 1인 (출시 책임자).
