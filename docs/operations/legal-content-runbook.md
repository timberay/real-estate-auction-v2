# Runbook: W0-3.4 — Terms / Privacy 본문 작성

**Date**: 2026-05-14
**Status**: 외부 작업 (법무 검토) 대기
**Related**: 로드맵 W0-3 (4/4 sub-item)

## Context

`/terms` 와 `/privacy` 라우트 + 컨트롤러 + 뷰 모두 가동 중. 본문은 placeholder:

- `db/seeds/legal_terms.md` — `# 정식 법무 검토 후 교체 예정`
- `db/seeds/legal_privacy.md` — 동일

뷰 (`app/views/legal/terms.html.erb`, `app/views/legal/privacy.html.erb`) 는 이미 markdown 렌더링
구현 완료 (LegalController#terms, #privacy → seed file 읽어서 redcarpet 으로 변환).

## Why this matters

한국 개인정보보호법 (PIPA) 및 정보통신망법상 개인정보 수집 / 이용을 하는 서비스는
이용약관 + 개인정보처리방침을 명시적으로 게시해야 함. 본 서비스는 OAuth 로그인 시 email,
nickname, profile 사진을 수집하므로 **출시 전 필수**.

## Execution

### Step 1: 초안 작성 (사용자 본인)

1. **이용약관** (Terms of Service) 항목 (한국 표준 골격):
   - 제1조 (목적)
   - 제2조 (정의)
   - 제3조 (이용계약 체결)
   - 제4조 (서비스의 제공)
   - 제5조 (서비스 이용 제한)
   - 제6조 (책임 제한 — 본 서비스는 분석 참고용, 법적 자문 아님)
   - 제7조 (분쟁 해결 — 한국 법원 관할)

2. **개인정보처리방침** (Privacy Policy) 항목:
   - 1. 수집하는 개인정보 항목 (OAuth 별 — email, nickname, profile_image_url)
   - 2. 수집/이용 목적 (서비스 인증, 사용자별 분석 데이터 저장)
   - 3. 보유/이용 기간 (회원 탈퇴 시 즉시 파기, 단 법령상 보존 의무 항목 별도)
   - 4. 제3자 제공 (LLM API call 시 사용자 작성 프롬프트가 외부 API 로 송신됨 — 명시 필수)
   - 5. 개인정보 처리 위탁 (없음 또는 Cafe24 호스팅)
   - 6. 정보주체 권리 (열람 / 정정 / 삭제 / 처리정지)
   - 7. 개인정보 보호책임자 (이름 / 연락처)

### Step 2: 법무 검토 (외부)

- 한국 법률 자문 (변호사 또는 한국개인정보보호위원회 표준양식 참고)
- 표준 양식: https://www.privacy.go.kr → 자료/소식 → 표준개인정보처리방침

### Step 3: seed 파일 갱신 + 배포

```bash
# 검토된 본문으로 두 파일 교체
$EDITOR db/seeds/legal_terms.md
$EDITOR db/seeds/legal_privacy.md

# DB 재시드 (운영에서는 직접 SQL 또는 rake task)
bin/rails db:seed:replant -- --only=legal

# 배포
bin/kamal deploy
```

### Step 4: 검증

- [ ] `/terms` 진입 → 새 본문 표시
- [ ] `/privacy` 진입 → 새 본문 표시
- [ ] 회원 가입 페이지에 두 링크 명시적 노출 (현재 `/auth/login` 에 추가 필요한지 검토)

## Open questions

- 회원 가입 시 이용약관 / 개인정보처리방침 동의 체크박스 필요? (OAuth 로 자동 가입되는 경우의 처리)
- 미성년자 가입 처리 방침
- 개인정보 보호책임자 정보 결정 (사용자 본인 정보)

## Owner

법무 검토: 외부 변호사 또는 사용자 본인 (개인정보보호위원회 표준양식 활용).
seed 파일 갱신: 코드 작업 (사용자 본인).
