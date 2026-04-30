# 2026-04-29 — Followup Tasks

After completing the sub-path deployment fixes (branch `fix/sub-path-deployment`, 9 commits), these are the remaining items.

---

## Immediate: Ship the sub-path fix branch

Branch is ready to merge. All tests green (863 runs, 0 failures), runtime smoke verified under `RAILS_RELATIVE_URL_ROOT=/real-estate-auction`.

```bash
# From the fix/sub-path-deployment branch:
/review              # pre-landing PR review
/ship                # create PR via push2gh
/land-and-deploy     # merge + deploy verification
/document-release    # post-ship docs sync
```

**Branch summary:**
- 9 commits, 14 files, +263/-12 lines
- 23 new tests (unit + integration + initializer + helper + component)
- New helper module: `app/lib/sub_path.rb`
- Pattern: 3 path-based filter fixes (`request.path` → `request.path_info`), 6 hardcoded-path fixes (→ named route helpers / `script_name`-aware), 3 config fixes (`silence_healthcheck_path`, CSP `report_uri`, mailer `default_url_options`).

---

## Short-term: Fix pre-existing `db/seeds.rb` bug

`bin/ci` fails at the `Tests:Seeds` step with:

```
NoMethodError: undefined method 'password=' for an instance of User
db/seeds.rb:57: in 'block in <main>'
```

**Status:** Pre-existing on `main` (verified). Unrelated to sub-path fixes. The User model does not have `password=` setter (no `has_secure_password`).

**Action:** Either remove the `user.password = ...` call from `db/seeds.rb:57`, or add `has_secure_password` to the User model if password auth is intended. Pick whichever matches current auth design (OAuth-only per the codebase, so likely just remove the seed line).

**Effort:** Trivial — single-file fix + verify `bin/ci` passes.

---

## Before launch (M1-M7): External OAuth console registrations

The sub-path rename changed callback URLs from `/real-estate-auction-v2/auth/<provider>/callback` to `/real-estate-auction/auth/<provider>/callback`. Each OAuth provider console must be updated before launch:

| Provider | Console | Redirect URI to register |
|----------|---------|--------------------------|
| Google | https://console.cloud.google.com/ → OAuth 2.0 Client IDs | `https://<prod-host>/real-estate-auction/auth/google_oauth2/callback` |
| Naver | https://developers.naver.com/apps/ → 내 애플리케이션 → 서비스 URL/Callback URL | `https://<prod-host>/real-estate-auction/auth/naver/callback` |
| Kakao | https://developers.kakao.com/ → 내 애플리케이션 → 카카오 로그인 → Redirect URI | `https://<prod-host>/real-estate-auction/auth/kakao/callback` |

Old `-v2` URIs can be removed after verifying production login works on the new path.

**Effort:** ~15 minutes total (console clicks).

---

## Out-of-scope (decisions deferred)

- **`production.rb:64` `host: "example.com"`** placeholder — needs real production domain decision before launch. Outside the sub-path fix scope.
- **`/terms`, `/privacy`** links in `app/views/auth/sessions/_modal.html.erb` — those Rails routes don't exist (pages not built yet). Either build the pages or remove the links from the modal before launch.
- **Stash `stash@{0}`** (`feat/playwright-rewrite-and-search: WIP: browser_client changes`) — preserved untouched. Decide whether to apply, drop, or convert into a dedicated branch when picking up that work.

---

## Reference

- Plan: `docs/superpowers/plans/2026-04-29-sub-path-deployment-fixes.md` (the executed plan)
- Branch: `fix/sub-path-deployment` (9 commits ready to merge)
- Audit context: 110 use cases reviewed (50 beginner + 60 expert) on 2026-04-29 confirming all surfaces handled.
