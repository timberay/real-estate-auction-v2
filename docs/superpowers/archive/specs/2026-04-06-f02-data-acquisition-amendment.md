# F02 Spec Amendment — Data Acquisition & Per-User Analysis

## Context

The original F02 spec (`2026-04-05-f02-safe-property-filtering-design.md`) defined the safety analysis flow but left gaps in:
1. How property data enters the system (only mock seeds, no user-facing acquisition)
2. Per-user analysis storage (PropertyCheckResult has no user_id)
3. Per-user safety ratings (safety_rating stored on shared Property record)

This amendment addresses these gaps while keeping all existing F02 analysis logic (checklist items, auto-check rules, safety rating calculation) unchanged.

## Data Model Changes

### New Table: `user_properties`

Join table between User and Property. Represents "this user has added this property to their list" and stores per-user analysis results.

| Column | Type | Notes |
|--------|------|-------|
| `user_id` | references | FK to users, not null |
| `property_id` | references | FK to properties, not null |
| `safety_rating` | integer (enum) | safe(0) / caution(1) / danger(2), nullable (unanalyzed) |
| `analyzed_at` | datetime | When analysis was last completed, nullable |
| `created_at` | datetime | When user added this property |
| `updated_at` | datetime | |

**Constraints:** Unique index on `(user_id, property_id)`.

### Migration: `property_check_results` — Add `user_id`

- Add `user_id` column (references users, not null)
- Replace unique index `(property_id, checklist_item_id)` with `(property_id, checklist_item_id, user_id)`
- Same property can have different check results per user

### Migration: `properties` — Remove per-user columns

- Remove `user_id` column (Property is now shared data, not user-owned)
- Remove `safety_rating` column (moved to `user_properties`)
- Property stores only objective data: case_number, court_name, address, prices, raw_data, status

### Model Changes

**UserProperty** (new):
```ruby
class UserProperty < ApplicationRecord
  belongs_to :user
  belongs_to :property
  enum :safety_rating, { safe: 0, caution: 1, danger: 2 }
  validates :user_id, uniqueness: { scope: :property_id }
end
```

**Property** (updated):
```ruby
class Property < ApplicationRecord
  has_many :user_properties, dependent: :destroy
  has_many :users, through: :user_properties
  has_many :property_check_results, dependent: :destroy
  validates :case_number, presence: true, uniqueness: true
end
```

**PropertyCheckResult** (updated):
```ruby
class PropertyCheckResult < ApplicationRecord
  belongs_to :property
  belongs_to :checklist_item
  belongs_to :user
  validates :property_id, uniqueness: { scope: [:checklist_item_id, :user_id] }
end
```

## Property Addition Flow

### User enters case number on properties/index

```
User types case_number (e.g., "2026타경1234") and clicks "물건 추가"
    │
    ├─ Property.find_by(case_number:) exists?
    │   ├─ YES → Skip API fetch
    │   │        UserProperty already exists for this user?
    │   │          ├─ YES → Flash: "이미 내 목록에 있는 물건입니다."
    │   │          └─ NO → Create UserProperty (user + property)
    │   │                  Flash: "이미 등록된 물건입니다. 내 목록에 추가했습니다."
    │   │        Redirect to properties/index
    │   │
    │   └─ NO → PropertyDataSyncService.call(case_number:)
    │            Adapter fetches data (mock or real)
    │            Property created with raw_data
    │            Create UserProperty (user + property)
    │            Flash: "물건이 추가되었습니다."
    │            Redirect to properties/index
    │
    └─ Adapter returns nil (data not found)?
        → Flash error: "해당 경매번호의 물건을 찾을 수 없습니다."
          Stay on properties/index
```

### Controller: `PropertiesController#create`

New action accepting `case_number` parameter. Handles the full flow above. Uses `POST /properties`.

### Route Addition

```ruby
resources :properties, only: [:index, :show, :create] do
  # ... existing analyses routes
end
```

## Mock Adapter Enhancement

### Deterministic Random Data Generation

When a case number is not in the predefined MOCK_DATA hash, generate plausible random data seeded from the case number itself. This ensures:
- Same case number always produces same data (deterministic)
- Different case numbers produce different data (variety)
- Data looks realistic (valid address formats, reasonable prices)

### Generation Strategy

```ruby
# In MockCourtAuctionAdapter
def fetch_data(case_number)
  return MOCK_DATA[case_number] if MOCK_DATA.key?(case_number)
  generate_random_property(case_number)
end

def generate_random_property(case_number)
  seed = case_number.bytes.sum
  rng = Random.new(seed)
  # Use rng to deterministically pick: property_type, address, prices,
  # risk factors, tenants, etc. from predefined pools
end
```

### Random Data Pools

- **Property types:** 아파트, 빌라/다세대, 오피스텔
- **Courts:** 서울중앙지방법원, 서울남부지방법원, 수원지방법원, 인천지방법원, etc.
- **Addresses:** Pool of realistic Korean addresses per court
- **Prices:** Appraisal 5,000~150,000만원 range, min_bid 60-80% of appraisal
- **Risk factors:** Each risk factor has independent probability (e.g., lien: 10%, tenant: 40%)

Same approach for `MockBuildingLedgerAdapter`.

## UI Changes

### properties/index — Case Number Input

Add a form at the top of the property list page:

```
┌─────────────────────────────────────────────┐
│ [경매번호 입력 필드: "2026타경1234"]  [물건 추가] │
└─────────────────────────────────────────────┘
│ 기존 필터 (Safe만 보기 등)                       │
│ 물건 카드 목록 ...                              │
```

- Input field with placeholder "경매번호를 입력하세요 (예: 2026타경1234)"
- POST to `properties#create`
- Turbo Frame for inline response (no full page reload)

### properties/index — User-Scoped List

- Property list now shows only properties in current user's `user_properties`
- Filter by `UserProperty.safety_rating` instead of `Property.safety_rating`
- Empty state: "아직 추가한 물건이 없습니다. 경매번호를 입력하여 물건을 추가하세요."

## Service Updates

### SafetyRatingService

Update to save rating on `UserProperty` instead of `Property`:

```ruby
SafetyRatingService.call(property:, user:)
# → updates UserProperty.find_by(user:, property:).safety_rating
```

### PropertyAnalysisService

Update to accept `user` parameter and scope check results to user:

```ruby
PropertyAnalysisService.call(property:, user:)
# → creates PropertyCheckResult records with user_id
```

### AutoCheckRunner

Update to accept `user` parameter and pass through to PropertyCheckResult creation.

## What Does NOT Change

- All 17 checklist items and their detection rules
- The 4-step analysis flow (auto-check → manual input → resolution → rating)
- Safety rating logic (danger if unresolvable risk, caution if resolvable, safe otherwise)
- Adapter interface (`fetch_data(case_number)` signature)
- Property schema for objective data (case_number, raw_data, prices, etc.)

## Testing

- Unit: UserProperty model validations and associations
- Unit: PropertyCheckResult with user_id scoping
- Unit: Mock adapter random data generation (deterministic for same case_number)
- Integration: Property addition flow (new + existing case_number)
- Integration: User-scoped property list and safety rating filter
- Integration: Analysis flow with user_id propagation
