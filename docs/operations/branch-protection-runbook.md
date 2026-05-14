# Runbook: W0-5 — Branch Protection 정책

**Date**: 2026-05-14
**Status**: 결정 + 실행 대기 — I2 self-hosted runner 선행
**Related**: 로드맵 W0-5, 의존: I2 self-hosted runner 결정

## Context

현재 GitHub repository 는 **private**, GitHub Pro 미구독으로 main branch protection rule 등록 불가.
모든 PR 이 squash-merge 후 main 으로 직접 들어가지만 status check / required review / linear history
보장이 없음.

## Options 평가

| Option | Cost | 보안 | 운영 부담 |
|---|---|---|---|
| **A. GitHub Pro 구독** ($4/user/월) | $48/년/계정 | 표준 | 낮음 (UI 설정만) |
| **B. (추천) Self-hosted runner + GitHub Free 유지 + 자율 규율** | $0 | 보통 (status check 가능, force-push 차단 불가) | 중 (CI 인프라 운영) |
| **C. Public repo 전환** | $0 | 낮음 (코드 노출) | 낮음 |

## Decision: B (1단계 → 향후 A 가능)

### 1단계: I2 self-hosted runner 도입 (별도 세션, [I2 결정](../decisions/2026-05-14-I2-self-hosted-runner.md))

CI 가 부활해야 status check 자체가 의미를 가짐. 본 runbook 의 모든 후속 단계는 I2 가 선행.

### 2단계: 자율 규율 (private repo + Free)

GitHub Free 에서 적용 가능한 항목:

- ✅ Required status checks (CI green 필수) — workflow 부활 후
- ✅ Squash merge enforce (PR 머지 정책) — repo Settings 에서 squash only 만 활성화
- ✅ Auto-delete head branches — repo Settings → Pull Requests
- ❌ Force-push 차단 (Pro 필요)
- ❌ Required reviewer (Pro 필요)
- ❌ Restrict who can push to main (Pro 필요)

### 3단계 (선택): GitHub Pro 구독 → 강제 규율 (협업 확대 시)

아래 trigger 발생 시 즉시 구독:

- 협업자 1명 이상 추가
- main 에 직접 push 사고 1건 이상 발생
- force-push 방지가 필요한 사고 발생

## Execution (2단계 only — 1단계 완료 가정)

### Repository settings

```
Settings → General → Pull Requests
  [✓] Allow squash merging
  [ ] Allow merge commits
  [ ] Allow rebase merging
  [✓] Automatically delete head branches
```

### Branch protection (Free tier 가능 범위)

```
Settings → Branches → Add rule for "main"
  [✓] Require a pull request before merging
  [✓] Require status checks to pass
      Required: ci / scan_ruby, ci / lint, ci / test, ci / system-test
  [✓] Require linear history
```

## Failure modes

| 증상 | 원인 | 조치 |
|---|---|---|
| status check pending 영구 | self-hosted runner 다운 | runner systemctl status 확인 |
| squash 외 merge 가 들어옴 | Settings → PR 정책 미반영 | 위 settings 재적용 |

## Owner

repo admin (사용자 본인).
