# OAuth Developer Setup

각 개발자는 직접 OAuth 앱을 생성해야 합니다. 자격증명은 `config/credentials/development.yml.enc` 에 다음 키로 저장합니다.

```yaml
google:
  client_id: "..."
  client_secret: "..."
naver:
  client_id: "..."
  client_secret: "..."
kakao:
  client_id: "..."
  client_secret: "..."
```

운영 도메인 콜백 URL 등록은 [oauth-redirect-uri-runbook.md](oauth-redirect-uri-runbook.md) 참조.

## Google

1. https://console.cloud.google.com → APIs & Services → Credentials → Web application
2. Authorized redirect URI: `http://localhost:3000/auth/google_oauth2/callback`
3. Scopes: `userinfo.email`, `userinfo.profile`

## Naver

1. https://developers.naver.com → Application 등록
2. Service URL: `http://localhost:3000`
3. Callback URL: `http://localhost:3000/auth/naver/callback`
4. 제공 정보: 이메일 주소, 별명, 프로필 사진

## Kakao

1. https://developers.kakao.com → Application 생성
2. 보안 → Client Secret 생성
3. 카카오 로그인 → 활성화 ON
4. Redirect URI: `http://localhost:3000/auth/kakao/callback`
5. 동의항목: **카카오계정(이메일) — 필수 동의**, **프로필 정보(닉네임)**, **프로필 사진**
