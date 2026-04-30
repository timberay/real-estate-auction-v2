# Architecture

System architecture, technology stack, and implementation patterns.

## Project Overview

Rails monolith with Hotwire (Turbo + Stimulus), SQLite, and Solid Cache/Queue/Cable.
Exact versions: see `Gemfile.lock` (Rails), `.ruby-version` (Ruby).

## Technology Stack

### Backend

- **Framework**: Ruby on Rails
- **Asset Pipeline**: Propshaft (Rails 8 default, replaces Sprockets)
  - **importmap-rails**: Default JS management without Node.js bundling
  - Use `bin/importmap pin <package>` to add JS dependencies

### Frontend

- **Strategy**: Hotwire (Turbo + Stimulus)
  - **Turbo**: SPA-like navigation and partial page updates
  - **Turbo Frames** for pagination/tabs (no full page reloads)
  - **Turbo Streams** for partial updates
  - **Stimulus**: Pure JavaScript controllers, data-attribute conventions (`data-controller`, `data-action`, `data-*-target`)
  - **No TypeScript** — use only JavaScript
- **Styling**: TailwindCSS
- **Components**: ViewComponent for reusable UI with Lookbook for previews

### Testing

- **Framework**: Minitest (Rails default)
- **System Tests**: Rails built-in system tests with Capybara
- **Fixtures**: Rails fixtures for test data

### Database & Infrastructure

- **SQLite** with Solid Trifecta (no Redis or external services needed):
  - **Solid Cache**: Database-backed cache (replaces Redis/Memcached)
  - **Solid Queue**: Database-backed job backend (replaces Sidekiq/Resque)
  - **Solid Cable**: Database-backed Action Cable adapter (replaces Redis pub/sub)
- **Multi-DB configuration**: Each Solid service uses a separate SQLite file to avoid write lock contention. Configure in `config/database.yml` with `cache:`, `queue:`, and `cable:` entries (Rails 8 default).

### Deployment

- **Proxy**: Thruster (Go-based proxy wrapping Puma on port 80, automatic HTTP/2, compression, X-Sendfile, asset caching)
- **Tool**: Kamal 2 (the only deploy tool wired in — see `config/deploy.yml`). No `docker-compose.yml` exists; do not assume Compose works locally.
- **Container**: `Dockerfile` (production); `/rails/storage` is the persistent volume for SQLite + ActiveStorage + Solid services; non-root runtime (UID/GID 1000).
- **CI/CD**: GitHub Actions (automated testing, linting, security checks)

### Sub-directory Deployment

> **This is the project's active deployment mode.** Production runs at `<host>/real-estate-auction/` — see `RAILS_RELATIVE_URL_ROOT` in `config/deploy.yml`. Treat the rules below as enforced, not hypothetical.

When deploying multiple projects on a single server under sub-paths (e.g., `example.com/my-app/`):

#### Environment & Rails Config

```bash
RAILS_RELATIVE_URL_ROOT=/my-app
```

```ruby
# config/environments/production.rb
config.relative_url_root = ENV.fetch("RAILS_RELATIVE_URL_ROOT", "/")
```

```ruby
# config.ru
map ENV.fetch("RAILS_RELATIVE_URL_ROOT", "/") do
  run Rails.application
end
```

#### Asset Pipeline (Propshaft)

- Always use `asset_path` / `asset_url` helpers — they respect `relative_url_root` automatically
- Never hardcode absolute paths like `/assets/...` in CSS or JS

#### Hotwire (Turbo + Stimulus)

- **Turbo Drive**: Set turbo-root meta tag in layout:
  ```erb
  <meta name="turbo-root" content="<%= config.relative_url_root %>">
  ```
- **Action Cable**: Adjust mount path in routes:
  ```ruby
  mount ActionCable.server => "#{config.relative_url_root}/cable"
  ```
- **Stimulus controllers**: Pass paths via `data-*` attributes or `<meta>` tags — never hardcode URL paths in JS

#### Reverse Proxy (nginx → Thruster)

```nginx
location /my-app/ {
    proxy_pass http://thruster-upstream/;  # trailing slash strips prefix
    proxy_set_header X-Forwarded-Prefix /my-app;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_for_addr;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

#### Kamal 2

```yaml
# config/deploy.yml
env:
  clear:
    RAILS_RELATIVE_URL_ROOT: /my-app
```

#### Checklist

| Item | Verify |
|------|--------|
| `*_path` / `*_url` helpers | Include prefix (no hardcoded absolute paths) |
| JS fetch/XHR paths | Receive base path from `data-*` or `<meta>` |
| Action Cable connection | WebSocket path includes prefix |
| `redirect_to` | Automatically includes prefix |
| Health check path | Adjust Kamal/load balancer health check URL |
| Solid Queue Web UI | Adjust mount path if exposed |

### Background Jobs

- **Backend**: Solid Queue (database-backed, no Redis)
- **Worker**: `bin/jobs` (Rails 8 default; wraps `SolidQueue::Cli`)
- **Use Cases**: Heavy API calls, email delivery, data processing
- **Recurring jobs**: Defined in `config/recurring.yml` (e.g., `GuestCleanupJob` daily 3am, `LoanPolicySyncJob` daily 6am)
- **Kamal**: Deploy as separate `job` role for resource isolation

## Architecture Patterns

### Service Objects

`app/services/*_service.rb` — Follow single responsibility principle, provide unified interface via `call` method.

### Adapter Pattern

API communication abstraction with mock support. Adapters live under `app/adapters/`, namespaced per provider family (`Llm::`, `CourtAuction::`) when multiple implementations exist.

Real example — `app/adapters/llm/base.rb`:

```ruby
module Llm
  class Base
    def self.for
      return Llm::Mock.new if ENV["USE_MOCK"] == "true"

      provider = ENV.fetch("LLM_PROVIDER", "anthropic")
      case provider
      when "anthropic" then Llm::Anthropic.new
      when "openai"    then Llm::OpenAi.new
      when "gemini"    then Llm::Gemini.new
      # ...
      end
    end

    def analyze(system:, prompt:, documents: [])
      raise NotImplementedError
    end
  end
end
```

- **Dev server**: `USE_MOCK=true` in `.env` for rapid feedback without network calls.
- **Tests**: Use constructor injection for test isolation instead of environment variables:
  ```ruby
  class SomeService
    def initialize(adapter: Llm::Base.for)
      @adapter = adapter
    end
  end
  # In tests: SomeService.new(adapter: Llm::Mock.new)
  ```

### Custom Errors

Group related errors under a module in `app/errors/<domain>.rb` and `rescue_from` in controllers. Example pattern from `app/errors/data_provider.rb`:

```ruby
module DataProvider
  class Error < StandardError; end

  class MissingCredentialError < Error; end
  class ConnectionError < Error; end
  class RateLimitError < Error; end
  # ...
end
```

### Authentication

OAuth-only via OmniAuth 2.x (no password). Providers: Google (`omniauth-google-oauth2`), Naver (`omniauth-naver`), Kakao (`omniauth-kakao-oauth2` — plain `omniauth-kakao` is pinned to omniauth 1.x and incompatible).

Session model: every visitor gets a `User` row. Guests (`guest: true`) are per-session, identified by a `guest_token`; account users (`guest: false`) have at least one row in `identities` (`provider`, `uid`, unique scope). `ApplicationController#ensure_current_user` restores the session from `session[:user_id]`, then from a signed `remember_token` cookie (account users only), otherwise creates a new guest.

OAuth callback pipeline:

1. `Auth::{Google,Kakao,Naver}Adapter#to_profile` — normalize omniauth `auth_hash` into `Auth::ProviderProfile` (`provider`, `uid`, `email`, `email_verified`, `name`, `avatar_url`). `email_verified` is tri-state: `true`, `false`, or `nil` (provider did not report).
2. `SessionCreator` — three cases:
   - **Case A** — existing `Identity(provider, uid)` → attach, merge current guest in.
   - **Case B** — `email` matches existing account user → attach new identity, merge.
   - **Case C** — new user → promote current guest in place (preserves all guest-owned data).
3. `GuestMerger` — dispatches per-association via `User.mergeable_reflections` (associations annotated with `merge_policy:` + `natural_key:`). Policies: `:prefer_guest` (guest wins on natural-key collisions), `:keep_target` (target wins; used for `api_credentials`).

Defense: `reset_session` after every successful callback, `rack-attack` throttles `/auth/*` POST at 10/min/IP, `Auth::Error` hierarchy is `rescue_from`-caught in `ApplicationController`.

Ops: `GuestCleanupJob` (scheduled daily 3am in `config/recurring.yml`) destroys guests inactive for 30 days; `last_seen_at` is throttled to one write per minute via `Rails.cache`.

Test helpers: `mock_omniauth` in `test_helper.rb`, `/testing/sign_in` and `/testing/set_remember_cookie` routes (test env only) for integration tests that need to seed session or cookie state.

### Caching Strategy

- **Fragment caching**: UI components that don't change frequently
- **API response caching**: External API call results (TTL setting required)
- Use Solid Cache as the backend

## UI/Frontend Rules

- **ViewComponent first**: Reusable UI lives under `app/components/<feature>/component.rb` + matching `*.html.erb`. The `lookbook` gem is bundled for previews, but no engine mount is configured in `config/routes.rb` yet — add `mount Lookbook::Engine, at: "/lookbook"` (development/test only) when previews are needed.
- **Stimulus controllers**: `app/javascript/controllers/`, registered via `index.js`. Use kebab-case identifiers (`data-controller="search"`, `data-action="input->search#submit"`, `data-search-target="input"`).
- **Turbo**: Use `turbo_frame_tag` for sub-page updates (pagination, tabs); use `format.turbo_stream` responses for partial DOM mutations after a write. Prefer Turbo over a manual XHR + DOM patch.
- **Korean copy**: Default to Korean text in views/components. Only route through `I18n.t` when a feature already uses a locale file (see [i18n](#internationalization-i18n)).
- **Consistency**: When creating a new component, look for an existing analogous component first and match its structure (template/CSS/Stimulus split).

## Internationalization (i18n)

The product is Korean-only; default copy is written in Korean directly in views and components. `I18n.t` is reserved for subsystems that benefit from key-based copy (currently the user manual under `app/components/manual/*` backed by `config/locales/manuals.ko.yml`). `config/locales/en.yml` covers Rails defaults only.

If a future feature requires `I18n.t`:
- Add keys to a feature-scoped YAML file under `config/locales/`
- Use the convention `[page_or_component].[element].[action]` (e.g., `t('login.button.submit')`)
- Do not pull in `mobility`, `rails-i18n`, or `i18n-tasks` until a clear need exists — they are not currently in the bundle

## Rails 8 — Do NOT Use (Removed/Deprecated)

- **Classic Autoloader**: Completely removed. Use Zeitwerk only.
- **Rails UJS**: Removed. Use Turbo instead.
- **Sprockets**: Replaced by Propshaft. Do not add `sprockets` gem.
- **Webpack/Webpacker**: Use importmap-rails instead.
- **`params.require().permit()` for new code**: Prefer `params.expect()`.
