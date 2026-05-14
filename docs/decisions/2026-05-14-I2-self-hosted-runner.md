# Decision: I2 — Self-Hosted GitHub Actions Runner

**Date**: 2026-05-14
**Decider**: 자동 추천 적용
**Status**: RECOMMENDED — 즉시 구현 (출시 일정에 영향 큰 블로커)
**Related**: 로드맵 I-2 (`docs/superpowers/plans/2026-05-10-post-launch-roadmap.md` § I-2)

## Context

2026-05-10 GitHub Actions 결제 차단 → 워크플로 임시 비활성화 (`.disabled` 접미사). 4개
워크플로 모두 disabled 상태:

- `.github/workflows/ci.yml.disabled` (5 parallel jobs: scan_ruby, scan_js, lint, test, system-test)
- `.github/workflows/automerge.yml.disabled`
- `.github/workflows/auto-label.yml.disabled`
- `.github/workflows/dependabot-automerge.yml.disabled`

GitHub Actions 의 부재로 W0-5 branch protection 도 결정 불가 상태 (status check 폴링 인프라 없음).

## Options

| Option | Monthly cost | Cafe24 RAM impact | Setup time | Maintenance |
|---|---|---|---|---|
| **A. GitHub Actions 결제 재개** | $50~100 | 0 | 0 (즉시 .disabled 제거) | 0 |
| **B. (추천) Self-hosted runner on Cafe24** | $0 | 2~3GB peak (test+system-test 직렬화 필수) | 2~3시간 | runner 업데이트 + Docker 컨테이너 격리 관리 |
| **C. CI 영구 비활성화 + 로컬 pre-push 훅** | $0 | 0 | 30분 (.husky 또는 git hook) | 개발자 자율에 의존, 회귀 위험 |

## Decision: B. Self-hosted runner

### 구현 단계 (별도 세션 권장)

1. **Cafe24 호스트 준비**
   - GitHub Actions runner 바이너리 다운로드 + systemd 등록
   - 사용자: `gh-runner` 비특권 계정
   - 작업 디렉토리: `/opt/gh-runner/` (디스크 10~15GB 확보)

2. **Repository 설정**
   - GitHub repo Settings → Actions → Runners → Add self-hosted runner
   - 토큰 등록 + label `self-hosted, cafe24`

3. **Workflow 활성화 + 적응**
   - 4개 `.yml.disabled` → `.yml` 이름 변경
   - `runs-on: ubuntu-latest` → `runs-on: self-hosted`
   - test + system-test job 을 **직렬화** (4GB RAM 제약, parallel OOM 방지)
   - Docker 컨테이너 isolation: `container: { image: ruby:3.4.8, options: --memory=2g }`
   - Playwright 브라우저 캐시 host 영구 mount (재설치 시간 절감)

4. **모니터링**
   - free RAM 알림 (mem < 500MB 지속 5분 → Slack/Telegram)
   - runner offline 알림 (30분 무응답)

### Risks

- **OOM** — test 실행 중 컨테이너 OOM kill → 플레이키 CI. 완화: `--memory=2g` 캡 + system-test 빈도 축소 (main only, not every PR)
- **Disk fill** — Docker 캐시 누적. 완화: 주간 cron `docker system prune --filter "until=168h"`
- **단일 host SPOF** — runner 가 1대뿐이면 호스트 다운 시 CI 정지. 완화: 매뉴얼 (수동 build 가능)

### Why not Option A?

월 $50~100 의 비용 자체는 작지만, 결제 재개가 의도적으로 차단된 정책 결정 (개인 프로젝트 코스트 통제) 을
존중. self-hosted 구현 시간 (2~3시간) 이 1년치 SaaS 비용 ($600~1200) 을 상쇄.

### Why not Option C?

로컬 hook 은 개발자 자율 의존이라 사용자 본인이 1인 운영하는 동안만 유효. 협업 확대 시 즉시 무력화.

## Implementation Trigger

**즉시** — branch protection (W0-5), automerge, dependency security (bundler-audit, brakeman) 모두 CI 부활을 전제. 본 결정은 다음 인프라 작업의 선행 조건.

## Owner

별도 세션 (인프라 / 배포 권한 필요).
