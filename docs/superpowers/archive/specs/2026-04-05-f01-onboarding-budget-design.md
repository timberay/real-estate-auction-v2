# F01 Onboarding Budget Setup — Design Spec

## 1. Overview

### Purpose

Design the first feature (F01) of the real estate auction service: an onboarding wizard that determines "what properties I can afford" through a 3-step questionnaire. The result sets the property search filter for F02 and persists as a reusable budget baseline.

### Key Requirements from SRS

- 3-step onboarding flow embedded in the service entry (no separate calculator menu)
- Formula: `(Available Cash - Total Reserve Funds) / (1 - Loan Ratio) = Maximum Biddable Amount`
- Result auto-sets F02 property search filter
- Settings editable anytime from My Page

### Additional Requirements (from brainstorming)

- **Dynamic loan policy data**: Government loan policies (LTV/DSR) fetched via Adapter pattern (Mock first, real API structure ready)
- **Guest authentication**: Auto-session with `guest@auction.local` / `123456` (no login screen)
- **All property types from day one**: Apartment, Villa, Officetel enabled; others pre-defined but disabled
- **Live/Snapshot separation**: Active settings reference live DB; completed reports are immutable point-in-time snapshots
- **Snapshot versioning**: Recalculate with current conditions to produce a new version, compare with previous
- **Unit conventions**: Amounts in 만원 (10,000 KRW), area in 평 or ㎡ (user selectable)
- **UI implementation**: MUST use `/rails-ui` skill for all screen/component work to ensure design token compliance

### Design Principles Applied

| SRS Principle | How Applied in F01 |
|---|---|
| Repetition & Mastery | Onboarding completion leads directly to "View properties" CTA, starting the analysis cycle |
| Overconfidence Prevention | Loan ratio shows policy source and disclaimer; calculated amount clearly labeled as estimate |
| Respect for Fieldwork | N/A for F01 (no property-specific analysis) |

---

## 2. Data Model

### Live Configuration Tables

```
users
  id              :integer, PK
  email           :string, unique, not null
  password_digest :string, not null
  created_at      :datetime
  updated_at      :datetime

property_types
  id         :integer, PK
  name       :string, not null        # "아파트", "빌라/다세대", "오피스텔"
  code       :string, unique, not null # "apartment", "villa", "officetel"
  enabled    :boolean, default: false
  sort_order :integer, default: 0

reserve_fund_defaults
  id                  :integer, PK
  property_type_id    :integer, FK → property_types
  area_range_min      :integer, not null  # ㎡
  area_range_max      :integer, not null  # ㎡
  repair_cost         :integer, not null  # 만원
  acquisition_tax_rate :decimal, not null # rate (e.g., 0.01 ~ 0.12)
  scrivener_fee       :integer, not null  # 만원
  moving_cost         :integer, not null  # 만원
  maintenance_fee     :integer, not null  # 만원

loan_policies
  id               :integer, PK
  property_type_id :integer, FK → property_types
  policy_name      :string, not null   # "디딤돌", "신생아특례", "일반주담대"
  loan_ratio       :decimal, not null  # 0.6 ~ 0.9
  description      :text
  source_url       :string
  effective_date   :date, not null
  expiry_date      :date               # null = currently active
  enabled          :boolean, default: true
  created_at       :datetime
  updated_at       :datetime
```

### User Settings (Live, Editable)

```
budget_settings
  id                    :integer, PK
  user_id               :integer, FK → users, unique
  available_cash        :integer              # 만원
  property_type_id      :integer, FK → property_types
  area_range_min        :integer              # ㎡
  area_range_max        :integer              # ㎡
  repair_cost           :integer              # 만원
  acquisition_tax       :integer              # 만원
  scrivener_fee         :integer              # 만원
  moving_cost           :integer              # 만원
  maintenance_fee       :integer              # 만원
  loan_policy_id        :integer, FK → loan_policies
  loan_ratio            :decimal
  max_bid_amount        :integer              # 만원 (calculated)
  area_unit             :string, default: "pyeong"  # "pyeong" | "sqm"
  completed_at          :datetime
  created_at            :datetime
  updated_at            :datetime
```

### Snapshots (Immutable, Point-in-Time)

```
budget_snapshots
  id                   :integer, PK
  user_id              :integer, FK → users
  property_case_id     :integer, nullable  # FK for future F02 linkage
  version              :integer, not null  # Nth calculation for same context
  parent_snapshot_id   :integer, nullable  # FK → budget_snapshots (recalculation origin)
  trigger              :string, not null   # "onboarding" | "manual_edit" | "recalculate"

  # Denormalized values (no FKs — immutable copy)
  available_cash        :integer            # 만원
  property_type_name    :string
  area_range            :string             # "59~84㎡"
  area_unit             :string
  repair_cost           :integer
  acquisition_tax       :integer
  scrivener_fee         :integer
  moving_cost           :integer
  maintenance_fee       :integer
  loan_policy_name      :string
  loan_ratio            :decimal
  max_bid_amount        :integer            # 만원
  calculated_at         :datetime, not null

  # Indexes
  index: [user_id, version]
  index: [parent_snapshot_id]
```

### Key Design Decisions

- **Snapshots have NO foreign keys** to live tables — all values copied at creation time. Policy deletion/change does not affect historical reports.
- **Snapshots are never modified** — recalculation creates a new version with `parent_snapshot_id` linking to the original.
- **All monetary values stored in 만원** — avoids floating point issues, matches user mental model.
- **Area stored in ㎡ internally** — converted to 평 for display when `area_unit = "pyeong"` (1평 = 3.305785㎡).

---

## 3. Service Architecture

### Directory Structure

```
app/adapters/
  loan_policy_adapter.rb              # Base — .for(:mock) / .for(:government_api)
  mock_loan_policy_adapter.rb         # Returns seed data
  government_loan_policy_adapter.rb   # Real government API calls

app/services/
  budget_calculation_service.rb       # Core max bid calculation
  budget_snapshot_service.rb          # Snapshot create / recalculate / compare
  loan_policy_sync_service.rb         # Government API → DB sync logic

app/jobs/
  loan_policy_sync_job.rb            # Solid Queue periodic execution
```

### Adapter Pattern

```ruby
# Base adapter interface
LoanPolicyAdapter.for(provider)
  # USE_MOCK=true  → MockLoanPolicyAdapter (returns seed data)
  # USE_MOCK=false → GovernmentLoanPolicyAdapter (calls real APIs)

# Unified interface
adapter.fetch_policies(property_type:)
  # → [{ policy_name:, loan_ratio:, description:, effective_date:, ... }]
```

### Government API Sources (for real adapter)

| Source | Data | Method |
|---|---|---|
| Financial Services Commission (금융위원회) Open API | LTV/DSR regulatory limits | REST API via data.go.kr |
| Korea Housing Finance Corp (HF/한국주택금융공사) | Didimdol/Bogeumjari loan terms | Page parsing |
| Housing & Urban Guarantee Corp (HUG) | Newborn special loan etc. | Page parsing |

### Loan Policy Sync Flow

```
LoanPolicySyncJob (Solid Queue, daily)
  → LoanPolicySyncService.call
    → adapter.fetch_policies (per enabled property_type)
    → diff against existing loan_policies
    → update changed records (manage effective_date / expiry_date)
    → log changes (admin notification in future)
```

### Budget Calculation Service

```ruby
BudgetCalculationService.call(
  available_cash:,          # 만원
  reserve_funds: {          # 만원 each
    repair:, acquisition_tax:, scrivener:, moving:, maintenance:
  },
  loan_ratio:               # decimal (0.6 ~ 0.9)
)
# Returns:
# {
#   total_reserves: Integer,
#   max_bid_amount: Integer,  # (cash - reserves) / (1 - ratio)
#   breakdown: { ... }
# }
```

### Budget Snapshot Service

```ruby
BudgetSnapshotService.create(user:, trigger:)
  # → reads current budget_settings + resolved values
  # → creates immutable snapshot record

BudgetSnapshotService.recalculate(snapshot:)
  # → reads CURRENT budget_settings + LATEST loan_policies
  # → creates new snapshot (version + 1, parent → original)

BudgetSnapshotService.compare(snapshot_a:, snapshot_b:)
  # → returns per-field diff with delta values
  # → e.g., { loan_ratio: { was: 0.7, now: 0.6 }, max_bid_amount: { was: 30000, now: 25000, delta: -5000 } }
```

---

## 4. Screen Flow & UI

> **IMPORTANT**: All screen and component implementation MUST use the `/rails-ui` skill to ensure design token compliance and consistent UI generation.

### Guest Auto-Session

```ruby
# ApplicationController
before_action :set_guest_user

def set_guest_user
  return if session[:user_id]
  guest = User.find_or_create_by(email: "guest@auction.local") do |u|
    u.password = "123456"
  end
  session[:user_id] = guest.id
end

# Future transition: replace with Rails 8 authentication generator
```

### Entry Flow

```
[First Visit]
  → guest session auto-created
  → check budget_settings.completed_at
    ├─ nil → redirect to /onboarding (Step 1)
    └─ present → / (home — property list placeholder for F02)
```

### Wizard Flow (Turbo Frame + Stimulus Hybrid)

All 3 steps render inside `<turbo-frame id="onboarding_wizard">`. Step transitions are server-rendered via Turbo Frame. Interactive elements use Stimulus controllers.

**Step 1 — Available Cash (유용자금)**
```
┌─────────────────────────────────────┐
│  투자 가능한 유용자금을 입력하세요        │
│                                     │
│  유용자금  [        30,000 ] 만원     │
│                                     │
│  ℹ️ 유용자금이란 현재 투자에 사용할 수   │
│     있는 현금을 말합니다                │
│                                     │
│                        [ 다음 → ]    │
└─────────────────────────────────────┘
```
- Input: `inputmode="numeric"`, suffix "만원"
- Validation: required, positive integer
- Stimulus: `number_format_controller` for comma formatting on input

**Step 2 — Reserve Funds (예비비 설정)**
```
┌─────────────────────────────────────┐
│  예비비를 설정하세요                    │
│                                     │
│  물건유형  [아파트 ▾]                  │
│  면적     [59~84 ▾]  (평 | ㎡)       │
│                                     │
│  ☑ 기본값 사용                        │
│                                     │
│  수리비         [  500 ] 만원         │
│  취득세         [  360 ] 만원         │
│  법무사비용      [   80 ] 만원         │
│  이사비용       [  150 ] 만원         │
│  체납관리비      [   50 ] 만원         │
│  ──────────────────────            │
│  예비비 합계      1,140 만원           │
│                                     │
│            [ ← 이전 ] [ 다음 → ]     │
└─────────────────────────────────────┘
```
- Stimulus `reserve_fund_controller`: "기본값 사용" toggle auto-fills from `reserve_fund_defaults`
- Stimulus `area_unit_controller`: 평/㎡ toggle converts display values
- Property type / area range change → fetch defaults via Turbo Frame (server-side lookup)
- Each field editable even with "기본값 사용" checked (overrides default)

**Step 3 — Loan Ratio (대출 비율)**
```
┌─────────────────────────────────────┐
│  대출 비율을 설정하세요                  │
│                                     │
│  적용 가능한 대출 정책:                  │
│  ○ 디딤돌 대출 (LTV 80%)             │
│  ● 일반 주담대 (LTV 70%)     ← 선택  │
│  ○ 신생아특례 (LTV 80%)              │
│                                     │
│  대출 비율 미세조정:                    │
│  60% [========●===] 90%             │
│            70%                      │
│                                     │
│  ── 예상 결과 (실시간) ──             │
│  최대입찰가: 85,333만원                │
│                                     │
│  ⚠️ 이 계산은 추정치입니다.             │
│     정확한 대출 한도는 금융기관에          │
│     확인하세요.                        │
│                                     │
│          [ ← 이전 ] [ 계산하기 ]      │
└─────────────────────────────────────┘
```
- Loan policies loaded from `loan_policies` (enabled, non-expired, matching property type)
- Stimulus `loan_slider_controller`: slider drag updates real-time preview
- Preview calculation runs client-side (same formula as server) for instant feedback
- Final calculation validated server-side on submit

**Complete Screen**
```
┌─────────────────────────────────────┐
│  🎉 예산 설정이 완료되었습니다!          │
│                                     │
│  ┌───────────────────────────┐     │
│  │ 최대입찰가  85,333만원      │     │
│  │ (약 8억 5,333만원)         │     │
│  └───────────────────────────┘     │
│                                     │
│  ── 비용 내역 ──                     │
│  유용자금          30,000만원         │
│  (-) 수리비          500만원          │
│  (-) 취득세          360만원          │
│  (-) 법무사비용        80만원          │
│  (-) 이사비용         150만원          │
│  (-) 체납관리비        50만원          │
│  = 실투자금         28,860만원        │
│  대출비율              70%            │
│  = 최대입찰가       85,333만원        │
│                                     │
│  적용 정책: 일반 주담대 (LTV 70%)      │
│  계산 기준일: 2026-04-05             │
│                                     │
│  [ 내 예산 범위 물건 보기 ]    ← CTA  │
│  설정 다시 하기                       │
└─────────────────────────────────────┘
```

### My Page (Settings)

```
GET /settings/budget → same 3-step form pre-filled with current values
                     → change triggers budget_settings update + new snapshot
                     → snapshot history list with "compare" action

GET /settings/budget/snapshots → version history
  v3 (recalculate, 2026-04-10) — 최대입찰가 75,000만원
  v2 (manual_edit, 2026-04-08) — 최대입찰가 85,333만원
  v1 (onboarding, 2026-04-05) — 최대입찰가 85,333만원

  [v1 vs v3 비교]
  대출비율:  70% → 60%  (정책 변경)
  최대입찰가: 85,333 → 75,000만원 (△-10,333만원)
```

---

## 5. Routing

```ruby
# config/routes.rb
root "home#index"

resource :onboarding, only: [] do
  collection do
    get  "/",     action: :step1, as: :start
    post :step1
    post :step2
    post :step3
    get  :complete
  end
end

namespace :settings do
  resource :budget, only: [:show, :update]
  resources :budget_snapshots, only: [:index, :show] do
    member do
      post :recalculate
    end
    collection do
      get :compare  # ?ids[]=1&ids[]=3
    end
  end
end
```

---

## 6. Stimulus Controllers

| Controller | Location | Purpose |
|---|---|---|
| `number_format_controller` | Step 1, 2 | Comma formatting for 만원 inputs |
| `reserve_fund_controller` | Step 2 | "기본값 사용" toggle, auto-fill defaults |
| `area_unit_controller` | Step 2 | 평/㎡ toggle with live conversion |
| `loan_slider_controller` | Step 3 | Loan ratio slider with real-time max bid preview |
| `navigation_controller` | All steps | Browser back button handling within wizard |

---

## 7. Implementation Constraints

- **TDD**: Red-Green-Refactor for all service objects and models
- **Tidy First**: Structural and behavioral changes in separate commits
- **Mock First**: `USE_MOCK=true` with `MockLoanPolicyAdapter` for development
- **UI Skill**: All screen/component work MUST invoke `/rails-ui` skill for design token compliance
- **E2E Testing**: Wizard flow verified with Playwright via `/e2e-testing` skill
- **Seed Data**: Property types, reserve fund defaults, and loan policies seeded via `db/seeds.rb`
- **No login screen**: Guest user auto-created on first visit
- **Amounts in 만원**: All monetary DB columns and calculations use 만원 as base unit
- **Area in ㎡ internally**: Display converts to 평 when user preference is `pyeong`

---

## 8. Acceptance Criteria

From SRS + brainstorming additions:

- [ ] 3-step wizard completes and produces a maximum biddable amount
- [ ] "기본값 사용" applies property-type and area-specific average values
- [ ] Calculation result persisted in `budget_settings` and retrievable/editable from My Page
- [ ] Onboarding completion redirects to home screen (property list placeholder)
- [ ] Changing budget settings on My Page updates settings + creates new snapshot
- [ ] Guest auto-session created on first visit (no login screen)
- [ ] All amounts displayed and input in 만원 units
- [ ] Area unit toggleable between 평 and ㎡
- [ ] Loan policies loaded dynamically from DB (seeded via Mock adapter)
- [ ] Loan policy adapter switches between Mock and real based on `USE_MOCK` env var
- [ ] Budget snapshots are immutable — recalculation creates new version
- [ ] Snapshot comparison shows per-field diff with delta values
- [ ] Disclaimer text displayed on calculation results
- [ ] Real-time preview updates on slider interaction (client-side calculation)

---

## 9. F02 Integration Points (Future)

These are **optional integrations** that activate when F02 is deployed:

- `budget_settings.max_bid_amount` → F02 search filter upper bound
- `budget_settings.property_type_id` → F02 default property type filter
- `budget_snapshots` → F02 property case linkage via `property_case_id`
