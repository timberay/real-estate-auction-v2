# 부동산 경매 서비스

한국 부동산 경매 초심자를 위한 분석 웹앱. PDF 기반 AI 분석과 점검항목으로 입찰 판단을 돕습니다.
자세한 기능은 앱에서 직접 확인하세요.

## Tech Stack

- Rails 8.1 / Ruby 3.4.8
- Hotwire (Turbo + Stimulus) + TailwindCSS + ViewComponent
- SQLite + Solid Cache / Queue / Cable
- Propshaft + ImportMap
- Docker + Kamal + Thruster

## 개발자 셋업

```bash
bin/setup        # 의존성 설치 및 DB 준비
bin/dev          # 개발 서버 실행 (Puma + asset watcher)
bin/rails test   # 테스트 실행
bin/ci           # 전체 CI 파이프라인 (lint, security, test, seed check)
```

`.ruby-version` 으로 Ruby 3.4.8 고정. Bundler 2.x 필요.

## 문서

- [CLAUDE.md](CLAUDE.md) — AI 어시스턴트 가이드라인 (진입점)
- [docs/standards/](docs/standards/) — RULES / STACK / TOOLS / QUALITY / WORKFLOW
- [docs/superpowers/specs/](docs/superpowers/specs/) — SRS 및 기술 설계
- [docs/operations/](docs/operations/) — 운영 runbook
