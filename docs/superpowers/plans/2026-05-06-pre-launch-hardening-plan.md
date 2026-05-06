# Pre-Launch Hardening Plan (D-13 → 2026-05-19)

**작성일**: 2026-05-06
**근거**: 4-에이전트 병렬 보안·기능·운영 감사 결과 + 사용자 검토 의견
**목표**: Cafe24 4GB 단일 서버 런칭(2026-05-19)에 앞서 **데이터 손실·계정 탈취·서비스 다운으로 직결되는 결함만** 제거. 코드 품질/성능 개선은 출시 후 백로그로 분리.

---

## 1. 적용 범위 — 필터링 결과

감사에서 도출된 40+ 항목 중 다음 4개 기준 중 1개 이상을 충족하는 항목만 "반드시"로 선정.

| 기준 | 의미 |
|------|------|
| A. 보안 | 계정 탈취·PII 노출·데이터 위변조로 직결 |
| B. 가용성 | 단일 서버 4GB 환경에서 OOM/디스크 고갈/락 경합으로 다운 가능 |
| C. 데이터 보존 | 장애 시 복구 불가 |
| D. 사일런트 실패 | 운영자가 인지 못 하는 채로 사용자 영향 누적 |

**제외 항목 (출시 후 백로그)**: N+1 쿼리, race condition (단순 UI 토글), 코드 중복, CSP enforcing 전환, 가격 단위 헬퍼 통일, rack-attack 룰 확장, find_or_create_by race rescue, 한글 NFC 정규화, 컨트롤러 비대화 리팩토링, 의존성 SHA 핀.

**제외 사유**: 사용자 영향이 있어도 출시 후 1주 내 hotfix로 충분히 처리 가능하며, 출시 전 회귀 테스트 시간을 인증/인가 구조 변경에 집중해야 함.

---

## 2. PR 단위 작업 계획

각 PR은 다음 원칙을 따른다:
- **Tidy First**: 구조 변경(인터페이스/concern 추출)과 동작 변경(검증 로직 추가)을 별도 커밋으로 분리.
- **TDD**: 실패 테스트 먼저 → 그린 → 리팩토링.
- **소형 PR**: 한 PR은 한 가지 기준(A/B/C/D)만 다루며 병합 후 즉시 다음 PR로.

### Phase 1 — 인증/인가 구조 (D-13 ~ D-11, 3일)

**Phase 1은 다른 모든 변경의 토대이므로 가장 먼저, 한 번에 끝낸다.** 회귀 발생 시 D-10 이후 작업이 모두 막히므로 이 기간에 풀 회귀 테스트 + 스테이징 검증 필수.

#### PR-1: Lazy Guest Creation 도입 (기준 A, B)
**변경 대상**: `app/controllers/application_controller.rb`

**Before**:
```ruby
def ensure_current_user
  ...
  @current_user = User.create!  # 모든 요청
end
```

**After**:
```ruby
def current_user
  @current_user ||= load_existing_user  # nil 가능
end

def require_authenticated_user
  return if current_user
  redirect_to new_session_path, alert: "로그인이 필요합니다"
end

def ensure_guest_user
  # 의미 있는 쓰기 액션 직전에만 호출
  @current_user ||= load_existing_user || create_guest_user!
end
```

**적용 규칙**:
- `ApplicationController`에 `before_action :require_authenticated_user` 기본값.
- 랜딩/로그인/온보딩 진입 컨트롤러만 `skip_before_action`.
- 게스트가 의미 있는 쓰기를 시도하는 액션(예: `properties#create`)에서 `ensure_guest_user` 호출 → DB row 최초 생성.

**테스트**:
- 봇이 `/`만 1000회 GET → `User.count` 변화 없음.
- 비인증 사용자가 `/properties/new`(의미 있는 액션) 진입 → guest user 생성됨.
- 기존 게스트의 remember_token 쿠키로 재진입 → 동일 user 복구.

**회귀 위험**: 기존 컨트롤러·뷰·서비스가 `current_user` 항상 truthy를 가정하고 있을 수 있음. `git grep -n "current_user"` 결과 100+ 지점을 모두 확인해 nil-safe로 수정.

#### PR-2: PropertyScopable Concern + IDOR 일괄 차단 (기준 A)
**변경 대상**:
- 신규: `app/controllers/concerns/property_scopable.rb`
- 수정: `properties_controller`, `properties/documents_controller`, `inspections/start_controller`, `inspections/tabs_controller`, `inspections/dividends_controller`, `inspections/source_doc_reviews_controller`, `inspections/grades_controller`

```ruby
module PropertyScopable
  extend ActiveSupport::Concern
  private
  def set_user_property
    pid = params[:property_id] || params[:id]
    @user_property = current_user.user_properties.find_by!(property_id: pid)
    @property = @user_property.property
  end
end
```

**주의**:
- `find_by!`로 다른 유저의 property 접근 시 404. (권한 정보 누설 방지를 위해 ActiveRecord::RecordNotFound는 일반 404로 처리.)
- `properties#destroy`는 이미 안전하지만 통일성을 위해 동일 concern 적용.

**테스트**: 사용자 A가 사용자 B의 `property_id`로 모든 endpoint 호출 → 404. fixtures에 `user_property` 없는 상태도 검증.

#### PR-3: OAuth `email_verified` 검증 (기준 A)
**변경 대상**: `app/services/session_creator.rb`

```ruby
if @profile.email.present? && @profile.email_verified == true &&
   (existing = User.find_by(email: @profile.email, guest: false))
  ...
end
```

**Provider별 매핑 검증**:
- Google: `info.email_verified` (boolean)
- Naver: `extra.raw_info.response.email_verified` (string "true" → boolean 변환 필요)
- Kakao: `kakao_account.is_email_verified` (boolean)

각 provider profile builder에서 boolean 정규화 확인 후 적용.

**테스트**: provider가 `email_verified=false` 반환 시 기존 user 미링크, 신규 identity로만 계정 생성됨.

#### PR-4: TestingController production 로드 차단 (기준 A)
**변경 대상**: `app/controllers/testing_controller.rb`

```ruby
if Rails.env.test?
  class TestingController < ApplicationController
    ...
  end
end
```

라우트 가드와 클래스 정의 가드 이중화로 환경 변수 오설정 방지.

---

### Phase 2 — 외부 노출/리소스 격리 (D-10 ~ D-8, 3일)

#### PR-5: Production SSL/Host 강제 (기준 A)
**변경 대상**: `config/environments/production.rb`, `config/deploy.yml`

```ruby
# production.rb
config.assume_ssl = true
config.force_ssl = true
config.hosts = [ENV.fetch("APP_HOST"), /.*\.#{Regexp.escape(ENV.fetch("APP_HOST"))}/]
config.ssl_options = { hsts: { expires: 1.year, subdomains: true, preload: true } }
```

```yaml
# deploy.yml
proxy:
  ssl: true
  host: <실제 도메인>
```

**검증**: 스테이징에서 HTTP 요청 → 301 HTTPS, 임의 Host 헤더 → 403.

#### PR-6: Playwright → ActiveJob 격리 + 동시성 제한 (기준 B)
**변경 대상**:
- 신규: `app/jobs/court_auction_search_job.rb`, `app/jobs/pdf_export_job.rb` (있다면)
- 수정: `app/controllers/search_results_controller.rb` (동기 호출 제거)
- `config/queue.yml` 또는 Solid Queue config에 동시성 제한

```ruby
class CourtAuctionSearchJob < ApplicationJob
  limits_concurrency to: 1, key: "court_browser"
  retry_on Faraday::TimeoutError, attempts: 3, wait: :polynomially_longer

  def perform(user_id, criteria)
    user = User.find(user_id)
    CourtAuctionSearchService.new(user: user, criteria: criteria).call
    Turbo::StreamsChannel.broadcast_replace_to(...)
  end
end
```

**컨트롤러 변경**: `create` 액션은 잡을 enqueue만 하고 즉시 turbo frame loading 상태 반환. 결과는 Turbo Stream broadcast로 푸시.

**검증**: 5명 동시 검색 → 모두 즉시 응답, 워커는 1개씩 순차 실행. Puma 스레드 점유 없음.

#### PR-7: PDF 업로드 검증 강화 (기준 A, B)
**변경 대상**: `app/models/property.rb` (validation), `app/controllers/properties/documents_controller.rb`, `app/controllers/inspections/start_controller.rb`, `app/controllers/analyses_controller.rb`

```ruby
# property.rb
validate :documents_size_and_magic

private
def documents_size_and_magic
  documents.each do |doc|
    errors.add(:documents, "5MB 초과") if doc.byte_size > 5.megabytes
    doc.open do |f|
      header = f.read(5)
      errors.add(:documents, "PDF 형식 아님") unless header == "%PDF-"
    end
  end
end
```

`analyses_controller#manual`의 `params[:json_file].read`도 동일하게 사이즈 가드(1MB).

**검증**: PDF 위장 HTML 첨부 시 거부, 5MB 초과 시 거부.

#### PR-8: Docker 로그 로테이션 (기준 B)
**변경 대상**: `config/deploy.yml`

```yaml
logging:
  driver: json-file
  options:
    max-size: "100m"
    max-file: "5"
```

**검증**: 배포 후 `docker inspect` 로 옵션 확인.

---

### Phase 3 — 데이터 보존·시크릿·관측성 (D-7 ~ D-5, 3일)

#### PR-9: SQLite 백업 자동화 (기준 C)
**변경 대상**:
- 신규: `lib/tasks/backup.rake`
- 신규: `script/backup_to_external.sh` (외부 스토리지 sync)
- Cafe24 호스트 cron 등록 (수동 단계, README 문서화)

```ruby
# lib/tasks/backup.rake
namespace :db do
  task backup: :environment do
    ts = Time.current.strftime("%Y%m%d-%H%M%S")
    dir = "/var/backups/auction/#{ts}"
    FileUtils.mkdir_p(dir)
    %w[production production_cache production_queue production_cable].each do |db|
      sh "sqlite3 storage/#{db}.sqlite3 \".backup '#{dir}/#{db}.sqlite3'\""
    end
    sh "find /var/backups/auction -mtime +14 -delete"
  end
end
```

cron: `0 4 * * * cd /rails && bin/rails db:backup && /opt/scripts/backup_to_external.sh`

**Litestream 도입**은 백로그(런칭 후 1주). 우선 cron + 외부 sync로 D-Day 안전망 확보.

**검증**: 백업 파일을 별도 환경에서 복원 → `Property.count` 일치.

#### PR-10: Gemini API 키 회수 + Credentials 이전 (기준 A)
**작업 순서** (시간 순서 중요):
1. Google AI Studio에서 기존 키 즉시 revoke.
2. 새 키 발급.
3. `bin/rails credentials:edit --environment production` 으로 `gemini.api_key` 등록.
4. `app/adapters/llm/gemini.rb`를 `Rails.application.credentials.dig(:gemini, :api_key)` 로 변경.
5. 또한 query string → 헤더로 이전:
   ```ruby
   req.headers["x-goog-api-key"] = key  # req.params["key"] 제거
   ```
6. `.env` 에서 `GEMINI_API_KEY` 제거.
7. `master.key`를 1Password 등 별도 보관소에 백업(서버 분실 = 전체 인증 불가).

**검증**: production deploy 후 LLM 호출 정상, access log에 키 미노출.

#### PR-11: LlmAnalysisLog PII 암호화 (기준 A)
**변경 대상**:
- `app/models/llm_analysis_log.rb`
- 신규 마이그레이션: 암호화 컬럼 길이 확보 (text → text 그대로, encrypts는 메타 prefix 추가 가능)

```ruby
class LlmAnalysisLog < ApplicationRecord
  encrypts :response_json
  encrypts :system_prompt
  encrypts :user_prompt
end
```

**기존 데이터 처리**:
- 운영 DB에 평문 데이터가 이미 적재돼 있다면 백필 잡 필요.
- 출시 전이므로 `LlmAnalysisLog.delete_all` (개발/스테이징 한정) 또는 백필.

**Active Record Encryption 키 설정**:
```
bin/rails db:encryption:init  # 출력을 credentials에 추가
```

**보존 정책 (출시 후 백로그 분리, 본 PR은 암호화만)**: 90일 후 자동 삭제 잡은 별도.

**검증**: 새로 생성된 row는 SQLite에서 직접 select 시 평문 미노출.

#### PR-12: Sentry 연동 (기준 D)
**변경 대상**:
- `Gemfile`: `gem "sentry-ruby"`, `gem "sentry-rails"`
- `config/initializers/sentry.rb`
- credentials에 DSN

```ruby
Sentry.init do |config|
  config.dsn = Rails.application.credentials.dig(:sentry, :dsn)
  config.breadcrumbs_logger = [:active_support_logger]
  config.traces_sample_rate = 0.1
  config.send_default_pii = false
  config.before_send = ->(event, _hint) {
    # email, tenant name 등 도메인 PII 추가 마스킹
    event
  }
end
```

**검증**: `Rails.error.report` 또는 의도적 raise → Sentry 이벤트 수신.

#### PR-13: PdfAnalysisJob retry 정책 분리 (기준 D)
**변경 대상**: `app/jobs/pdf_analysis_job.rb`, `app/services/pdf_analysis_service.rb`

```ruby
class PdfAnalysisJob < ApplicationJob
  retry_on Faraday::TimeoutError, attempts: 3, wait: :polynomially_longer
  retry_on Faraday::ServerError, attempts: 3, wait: :polynomially_longer
  retry_on ActiveRecord::ConnectionTimeoutError, attempts: 5, wait: 1.minute
  discard_on ActiveJob::DeserializationError
  discard_on Llm::InvalidResponseError  # 데이터/파싱 실패는 재시도 무의미

  def perform(...)
    PdfAnalysisService.new(...).call
  rescue Llm::InvalidResponseError => e
    # 사용자 토스트만 띄우고 silently discard
    notify_user(e.user_message)
  end
end
```

**검증**: 일시적 503 → 재시도 후 성공. 잘못된 PDF → 1회 실패 후 사용자에게 메시지 + dead 큐 미적재.

---

### Phase 4 — 출시 직전 검증 (D-4 ~ D-Day, 4일)

#### D-4: 스테이징 풀 회귀 테스트
- `bin/rails test` + `bin/rails test:system` 전체 통과.
- 스테이징에서 OAuth 3개 provider 모두 로그인 시나리오 수동 검증.
- 다른 유저 자원 접근 시도(IDOR) 수동 검증.

#### D-3: 부하 테스트
- 스테이징에 5/10/20 동시 사용자로 검색·분석 시나리오.
- 메모리·디스크 사용량 모니터링.
- Playwright 잡이 동시성 1개로 제한되는지 확인.

#### D-2: 백업 복구 리허설
- 백업 파일을 새 환경에 복원 → 데이터 일치 확인.
- `master.key` 분실 시나리오 리허설 (백업 보관소에서 복구 가능 확인).

#### D-1: 최종 deploy.yml 점검
- 실서버 IP/도메인 반영, registry 자격증명, secrets 주입 확인.
- `kamal deploy --dry-run`.

#### D-Day: 점진적 cutover
- 내부 사용자만 먼저 노출.
- Sentry/로그 30분 모니터링 후 전체 공개.

---

## 3. 리스크 및 완화책

| 리스크 | 영향 | 완화 |
|--------|------|------|
| Phase 1 인증 리팩토링이 기존 테스트를 광범위하게 깨뜨림 | 일정 지연 | D-13 ~ D-11 3일 통째로 할당, 다른 작업과 병행 금지 |
| Playwright 비동기화로 기존 동기 가정 UI 깨짐 | UX 저하 | Turbo Stream으로 결과 푸시, "검색 중" 로딩 상태 명시 |
| Active Record Encryption 키 분실 = 기존 LLM 로그 복호화 불가 | 데이터 영구 손실 | 키를 master.key와 별도 위치에 이중 백업 |
| `force_ssl` 활성화로 Kamal proxy 미준비 시 즉시 다운 | 출시 차단 | 스테이징에서 먼저 검증, deploy 전 proxy.ssl 확정 |
| Cafe24 호스트 cron 권한 부재 | 백업 미작동 | 호스팅 정책 사전 확인, 불가 시 잡 스케줄러로 대체 |

---

## 4. 출시 후 1주 내 처리 (백로그)

본 계획에서 의도적으로 제외했지만 출시 후 hotfix로 처리:

1. `Property#analyzed?` N+1 (UX 개선)
2. `toggle_favorite` atomic UPDATE (드문 race)
3. 가격 단위 헬퍼 (`BudgetSetting#max_bid_amount_won`)
4. rack-attack 룰 확장
5. CSP `report_only=false` 전환
6. `permissions_policy.rb` 추가
7. `last_provider` 쿠키 hardening
8. `find_or_create_by` race rescue 헬퍼
9. `inspections/dividends_controller` 서비스 추출
10. `LlmAnalysisLog` 90일 보존 정책 잡
11. Litestream 도입 검토

---

## 5. 진행 체크리스트

### Phase 1 (D-13 ~ D-11)
- [ ] PR-1: Lazy Guest Creation
- [ ] PR-2: PropertyScopable Concern (IDOR)
- [ ] PR-3: OAuth email_verified
- [ ] PR-4: TestingController production 로드 차단

### Phase 2 (D-10 ~ D-8)
- [ ] PR-5: Production SSL/Host
- [ ] PR-6: Playwright ActiveJob 격리
- [ ] PR-7: PDF 업로드 검증
- [ ] PR-8: Docker 로그 로테이션

### Phase 3 (D-7 ~ D-5)
- [ ] PR-9: SQLite 백업 자동화
- [ ] PR-10: Gemini 키 회수 + credentials
- [ ] PR-11: LlmAnalysisLog 암호화
- [ ] PR-12: Sentry 연동
- [ ] PR-13: PdfAnalysisJob retry 정책

### Phase 4 (D-4 ~ D-Day)
- [ ] 풀 회귀 테스트
- [ ] 부하 테스트
- [ ] 백업 복구 리허설
- [ ] deploy.yml 최종 점검
- [ ] 점진적 cutover

---

**총 13 PR / 12일 / 평균 1 PR/일**. Phase 1은 토대라 3일 단독, 이후는 병렬 가능 항목 분할 가능.

다음 단계: 어느 PR부터 착수할지 결정. PR-1(Lazy Guest)이 의존성 정점이므로 권장.
