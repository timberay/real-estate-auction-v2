# 관리자 (Admin) 운영 가이드

## 첫 관리자 부여 (Bootstrap)

`/admin/*` 라우트는 `users.admin = true` 인 계정만 접근 가능합니다. 비-관리자는
404로 라우트의 존재 자체가 가려집니다.

마이그레이션 직후 `admin = true` 인 사용자가 한 명도 없으므로, Rails console
에서 직접 부여해야 합니다:

```bash
bin/rails console -e production
> User.find_by(email: "you@example.com").update!(admin: true)
```

개발 환경에서는:

```bash
bin/rails console
> User.find_by(email: "you@example.com").update!(admin: true)
```

OAuth 로그인을 한 번 거친 뒤에야 `User` 행이 만들어지므로, 부여하려는 계정으로
먼저 로그인해 본 다음 console 에서 위 명령을 실행하세요.

## 사용 가능한 어드민 화면

| 경로 | 용도 | 라우트 |
|---|---|---|
| `/admin/acquisition_tax_rates` | 취득세율 목록 + 수정 | `admin/acquisition_tax_rates#index, #edit, #update` |

생성/삭제는 의도적으로 빠져 있습니다. 새 행을 추가하거나 폐기하려면 별도
마이그레이션/시드 PR 또는 후속 작업(F-D-2)에서 다룹니다.

## 권한 변경/회수

관리자 자격을 회수할 때도 동일하게 console 에서:

```bash
> User.find_by(email: "you@example.com").update!(admin: false)
```

UI 로 권한을 부여/회수하는 흐름은 현재 없으며, 이는 의도된 설계입니다 — 권한
승격은 코드/DB 직접 접근을 필요로 하는 통로만 남깁니다.
