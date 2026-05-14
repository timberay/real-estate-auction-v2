# Runbook: W0-2 — OAuth Console Redirect URI 등록

**Date**: 2026-05-14
**Status**: 외부 설정 작업 — 운영 도메인 확정 후 실행
**Related**: 로드맵 W0-2, 코드 상태: `config/initializers/omniauth.rb` (변경 불필요)

## What this runbook does

3개 OAuth provider (Google / Naver / Kakao) 의 개발자 콘솔에 production callback URL 을
등록. **코드 변경 없음** — 모두 외부 콘솔 작업.

## Pre-requisites

- [ ] `APP_HOST` 환경변수 확정 (예: `auction.timberay.com`)
- [ ] HTTPS TLS 인증서 발급 완료 (Let's Encrypt 또는 Cafe24 제공)
- [ ] Production deploy 1회 성공 → `https://{APP_HOST}/auth/login` 접근 가능 확인

## Execution

### Google Cloud Console

1. https://console.cloud.google.com → 본 프로젝트 선택
2. APIs & Services → **Credentials**
3. OAuth 2.0 Client IDs → Web application (이미 dev 용 등록되어 있음)
4. **Authorized redirect URIs** 섹션에 추가:
   ```
   https://{APP_HOST}/auth/google_oauth2/callback
   ```
5. Save → 5분 정도 GCP 전파 대기

### Naver Developers

1. https://developers.naver.com → 본 application 선택
2. API 설정 → **서비스 환경**
3. **Callback URL** 추가 (기존 `localhost:3000` 옆에):
   ```
   https://{APP_HOST}/auth/naver/callback
   ```
4. **서비스 URL** 도 함께 갱신:
   ```
   https://{APP_HOST}
   ```
5. Save → 즉시 반영

### Kakao Developers

1. https://developers.kakao.com → 본 application 선택
2. **카카오 로그인** → **Redirect URI** 추가:
   ```
   https://{APP_HOST}/auth/kakao/callback
   ```
3. (이미 dev 등록되어 있다면 추가만, dev URI 는 유지)
4. Save → 즉시 반영

## Verification

각 provider 마다 **production round-trip 테스트**:

1. 시크릿/익명 창에서 `https://{APP_HOST}/auth/login` 진입
2. Provider 버튼 클릭 → consent 화면 → 승인
3. `/auth/{provider}/callback` 으로 redirect → 로그인 완료 확인
4. `current_user` 정상 (sidebar 사용자 이름 표시)
5. 로그아웃 → 재로그인 1회 더 (token refresh 동작 확인)

## Failure modes

| 증상 | 원인 | 조치 |
|---|---|---|
| `redirect_uri_mismatch` (Google) | URI 등록 누락 또는 후행 슬래시 mismatch | URI 정확히 일치하는지 확인 (https vs http, 후행 / 유무) |
| Naver `error_code=4001` | Callback URL 미등록 | 위 단계 재실행 |
| Kakao `KOE006` | Redirect URI 미등록 | 위 단계 재실행 |
| OAuth 콜백 후 로그인 실패 | Symbol provider 회귀 (이미 #167 에서 fixed) | 본 issue 가 다시 보이면 #167 PR 회귀 의심, 별도 조사 |

## Owner

콘솔 권한 보유자 (사용자 본인).
