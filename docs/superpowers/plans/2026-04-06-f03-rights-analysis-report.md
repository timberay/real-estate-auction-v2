# F03 Rights Analysis Report — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an automated rights analysis engine that extracts extinguishment base rights, determines tenant opposing power, calculates assumed amounts, simulates dividends, and presents results in a structured report with overconfidence prevention.

**Architecture:** Single orchestrator service (`RightsAnalysisService`) delegates to 5 focused sub-modules. Results are persisted in a new `rights_analysis_reports` table. The property detail page is restructured with ①②③④ numbered tabs. A `MockRegistryAdapter` provides deterministic test data following the existing adapter pattern.

**Tech Stack:** Rails 8.1, Minitest, ViewComponent, Stimulus, Turbo Frames, TailwindCSS, SQLite

**Spec:** `docs/superpowers/specs/2026-04-06-f03-rights-analysis-report-design.md`

---

## File Map

### New Files

| File | Responsibility |
|---|---|
| `db/migrate/TIMESTAMP_create_rights_analysis_reports.rb` | Migration for rights_analysis_reports table |
| `app/models/rights_analysis_report.rb` | Model with enum, validations, associations |
| `app/adapters/registry_transcript_adapter.rb` | Base adapter with `.for` factory |
| `app/adapters/mock_registry_transcript_adapter.rb` | Mock data + deterministic random generation |
| `app/services/rights_analysis/extinguishment_base_right_extractor.rb` | Extract base right from registry |
| `app/services/rights_analysis/opposing_power_determiner.rb` | Determine tenant opposing power |
| `app/services/rights_analysis/assumed_amount_calculator.rb` | Calculate assumed amount |
| `app/services/rights_analysis/dividend_simulator.rb` | Simulate dividend distribution |
| `app/services/rights_analysis/opportunity_detector.rb` | Detect HUG waiver + full-dividend opportunities |
| `app/services/rights_analysis_service.rb` | Orchestrator calling all 5 sub-modules |
| `app/controllers/analyses/reports_controller.rb` | show + update actions for report tab |
| `app/controllers/analyses/checklists_controller.rb` | Renamed from results_controller |
| `app/components/property_tabs_component.rb` | Tab navigation with ①②③④ |
| `app/components/property_tabs_component.html.erb` | Tab template |
| `app/components/report_summary_component.rb` | Section 1 — verdict + summary |
| `app/components/report_summary_component.html.erb` | Summary template |
| `app/components/registry_timeline_component.rb` | Section 2 — timeline |
| `app/components/registry_timeline_component.html.erb` | Timeline template |
| `app/components/dividend_simulator_component.rb` | Section 3 — dividend table |
| `app/components/dividend_simulator_component.html.erb` | Dividend template |
| `app/components/source_doc_viewer_component.rb` | Section 4 — source docs |
| `app/components/source_doc_viewer_component.html.erb` | Source doc template |
| `app/components/legal_disclaimer_component.rb` | Legal disclaimer |
| `app/components/legal_disclaimer_component.html.erb` | Disclaimer template |
| `app/views/analyses/reports/show.html.erb` | Report tab view |
| `app/views/analyses/checklists/edit.html.erb` | Renamed from results/edit |
| `app/javascript/controllers/property_tabs_controller.js` | Tab switching |
| `app/javascript/controllers/dividend_simulator_controller.js` | Bid input + calculation |
| `app/javascript/controllers/source_doc_tracker_controller.js` | Source doc tracking + popup |
| `test/models/rights_analysis_report_test.rb` | Model tests |
| `test/services/rights_analysis/extinguishment_base_right_extractor_test.rb` | Extractor tests |
| `test/services/rights_analysis/opposing_power_determiner_test.rb` | Opposing power tests |
| `test/services/rights_analysis/assumed_amount_calculator_test.rb` | Assumed amount tests |
| `test/services/rights_analysis/dividend_simulator_test.rb` | Dividend tests |
| `test/services/rights_analysis/opportunity_detector_test.rb` | Opportunity tests |
| `test/services/rights_analysis_service_test.rb` | Orchestrator tests |
| `test/controllers/analyses/reports_controller_test.rb` | Controller tests |
| `test/components/report_summary_component_test.rb` | Component tests |
| `test/components/registry_timeline_component_test.rb` | Component tests |
| `test/components/dividend_simulator_component_test.rb` | Component tests |
| `test/components/property_tabs_component_test.rb` | Component tests |
| `test/components/source_doc_viewer_component_test.rb` | Component tests |
| `test/fixtures/rights_analysis_reports.yml` | Test fixtures |

### Modified Files

| File | Change |
|---|---|
| `app/models/user.rb` | Add `has_many :rights_analysis_reports` |
| `app/models/property.rb` | Add `has_many :rights_analysis_reports` |
| `app/controllers/analyses/start_controller.rb` | Add `RightsAnalysisService.call` alongside existing service |
| `app/services/property_data_sync_service.rb` | Add `RegistryTranscriptAdapter` data to `raw_data` |
| `config/routes.rb` | Add `report` resource, rename `result` → `checklist` |
| `app/views/properties/show.html.erb` | Restructure with PropertyTabsComponent |

---

## Task 1: Migration — Create `rights_analysis_reports` Table

**Files:**
- Create: `db/migrate/TIMESTAMP_create_rights_analysis_reports.rb`

- [ ] **Step 1: Generate migration**

Run:
```bash
bin/rails generate migration CreateRightsAnalysisReports
```

- [ ] **Step 2: Write migration**

Edit the generated file:

```ruby
class CreateRightsAnalysisReports < ActiveRecord::Migration[8.1]
  def change
    create_table :rights_analysis_reports do |t|
      t.references :user, null: false, foreign_key: true
      t.references :property, null: false, foreign_key: true
      t.string :base_right_type
      t.date :base_right_date
      t.string :base_right_holder
      t.integer :assumed_amount, default: 0, null: false
      t.integer :total_risk_amount, default: 0, null: false
      t.integer :verdict, default: 0, null: false
      t.text :verdict_summary
      t.string :opportunity_type
      t.text :opportunity_reason
      t.boolean :source_doc_reviewed, default: false, null: false
      t.datetime :analyzed_at, null: false
      t.json :report_data
      t.timestamps
    end
    add_index :rights_analysis_reports, [ :user_id, :property_id ], unique: true, name: "idx_rights_reports_user_property"
  end
end
```

- [ ] **Step 3: Run migration**

Run: `bin/rails db:migrate`
Expected: Schema updated with `rights_analysis_reports` table.

- [ ] **Step 4: Verify schema**

Run: `bin/rails db:schema:dump && grep -A 20 "rights_analysis_reports" db/schema.rb`
Expected: Table definition matches migration.

- [ ] **Step 5: Commit**

```bash
git add db/migrate/*_create_rights_analysis_reports.rb db/schema.rb
git commit -m "feat(f03): add rights_analysis_reports migration"
```

---

## Task 2: Model — RightsAnalysisReport

**Files:**
- Create: `app/models/rights_analysis_report.rb`
- Create: `test/models/rights_analysis_report_test.rb`
- Create: `test/fixtures/rights_analysis_reports.yml`
- Modify: `app/models/user.rb`
- Modify: `app/models/property.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# test/models/rights_analysis_report_test.rb
require "test_helper"

class RightsAnalysisReportTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
    @property = properties(:safe_apartment)
  end

  test "valid with required attributes" do
    report = RightsAnalysisReport.new(
      user: @user,
      property: @property,
      verdict: :safe,
      analyzed_at: Time.current
    )
    assert report.valid?
  end

  test "invalid without user" do
    report = RightsAnalysisReport.new(property: @property, verdict: :safe, analyzed_at: Time.current)
    assert_not report.valid?
  end

  test "invalid without property" do
    report = RightsAnalysisReport.new(user: @user, verdict: :safe, analyzed_at: Time.current)
    assert_not report.valid?
  end

  test "enforces unique user-property pair" do
    RightsAnalysisReport.create!(user: @user, property: @property, verdict: :safe, analyzed_at: Time.current)
    duplicate = RightsAnalysisReport.new(user: @user, property: @property, verdict: :caution, analyzed_at: Time.current)
    assert_not duplicate.valid?
  end

  test "verdict enum values" do
    report = RightsAnalysisReport.new(user: @user, property: @property, analyzed_at: Time.current)
    report.verdict = :safe
    assert report.safe?
    report.verdict = :caution
    assert report.caution?
    report.verdict = :danger
    assert report.danger?
  end

  test "user association" do
    assert_respond_to @user, :rights_analysis_reports
  end

  test "property association" do
    assert_respond_to @property, :rights_analysis_reports
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/rights_analysis_report_test.rb`
Expected: FAIL — `NameError: uninitialized constant RightsAnalysisReport`

- [ ] **Step 3: Create fixture**

```yaml
# test/fixtures/rights_analysis_reports.yml
safe_apartment_report:
  user: guest
  property: safe_apartment
  base_right_type: "근저당"
  base_right_date: "2024-01-15"
  base_right_holder: "국민은행"
  assumed_amount: 0
  total_risk_amount: 0
  verdict: 0
  verdict_summary: "말소기준권리: 근저당 (2024-01-15, 국민은행)\n임차인 없음\n인수 금액 0원"
  source_doc_reviewed: false
  analyzed_at: <%= Time.current %>
  report_data: '<%= { registry_timeline: [], tenants: [], dividend_simulation: { expected_bid: nil, distribution: [] }, bidder_burden: { assumed_amount: 0, unconfirmed_risk: 0, total_burden: 0, verdict: "safe" }, checklist_references: [] }.to_json %>'

risky_villa_report:
  user: guest
  property: risky_villa
  base_right_type: "근저당"
  base_right_date: "2023-06-01"
  base_right_holder: "신한은행"
  assumed_amount: 30000000
  total_risk_amount: 30000000
  verdict: 2
  verdict_summary: "말소기준권리: 근저당 (2023-06-01, 신한은행)\n대항력 있는 임차인 1명 — 보증금 3,000만원 인수\n유치권 신고 있음"
  opportunity_type:
  opportunity_reason:
  source_doc_reviewed: false
  analyzed_at: <%= Time.current %>
  report_data: '<%= { registry_timeline: [], tenants: [], dividend_simulation: { expected_bid: nil, distribution: [] }, bidder_burden: { assumed_amount: 30000000, unconfirmed_risk: 0, total_burden: 30000000, verdict: "danger" }, checklist_references: ["rights-011"] }.to_json %>'
```

- [ ] **Step 4: Create model and update associations**

```ruby
# app/models/rights_analysis_report.rb
class RightsAnalysisReport < ApplicationRecord
  belongs_to :user
  belongs_to :property

  enum :verdict, { safe: 0, caution: 1, danger: 2 }

  validates :user_id, uniqueness: { scope: :property_id }
  validates :analyzed_at, presence: true
end
```

Add to `app/models/user.rb`:
```ruby
has_many :rights_analysis_reports, dependent: :destroy
```

Add to `app/models/property.rb`:
```ruby
has_many :rights_analysis_reports, dependent: :destroy
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/models/rights_analysis_report_test.rb`
Expected: All 7 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/models/rights_analysis_report.rb app/models/user.rb app/models/property.rb test/models/rights_analysis_report_test.rb test/fixtures/rights_analysis_reports.yml
git commit -m "feat(f03): add RightsAnalysisReport model with associations"
```

---

## Task 3: Adapter — MockRegistryTranscriptAdapter

**Files:**
- Create: `app/adapters/registry_transcript_adapter.rb`
- Create: `app/adapters/mock_registry_transcript_adapter.rb`
- Create: `test/adapters/mock_registry_transcript_adapter_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# test/adapters/mock_registry_transcript_adapter_test.rb
require "test_helper"

class MockRegistryTranscriptAdapterTest < ActiveSupport::TestCase
  setup do
    @adapter = MockRegistryTranscriptAdapter.new
  end

  test "returns predefined data for known case numbers" do
    data = @adapter.fetch_data(case_number: "2026타경10001")
    assert_not_nil data
    assert data.key?(:rights)
    assert data.key?(:tenants)
    assert data.key?(:hug_waiver)
    assert data.key?(:seizures)
  end

  test "generates deterministic random data for unknown case numbers" do
    data1 = @adapter.fetch_data(case_number: "2099타경99999")
    data2 = @adapter.fetch_data(case_number: "2099타경99999")
    assert_equal data1, data2
  end

  test "different case numbers produce different data" do
    data1 = @adapter.fetch_data(case_number: "2099타경11111")
    data2 = @adapter.fetch_data(case_number: "2099타경22222")
    assert_not_equal data1[:rights].first[:holder], data2[:rights].first[:holder]
  end

  test "generated rights have required fields" do
    data = @adapter.fetch_data(case_number: "2099타경99999")
    right = data[:rights].first
    assert right.key?(:type)
    assert right.key?(:date)
    assert right.key?(:holder)
    assert right.key?(:amount)
    assert right.key?(:status)
    assert right.key?(:registry_section)
  end

  test "generated tenants have required fields" do
    # Use a case number that generates tenants (deterministic)
    # Try several until we find one with tenants
    data = nil
    (1..20).each do |i|
      data = @adapter.fetch_data(case_number: "2099타경#{10000 + i}")
      break if data[:tenants].any?
    end
    return if data[:tenants].empty? # skip if no tenants generated

    tenant = data[:tenants].first
    assert tenant.key?(:name)
    assert tenant.key?(:deposit)
    assert tenant.key?(:move_in_date)
    assert tenant.key?(:confirmed_date)
    assert tenant.key?(:dividend_requested)
    assert tenant.key?(:is_small_sum_tenant)
  end

  test "factory method returns mock adapter when USE_MOCK is not false" do
    adapter = RegistryTranscriptAdapter.for
    assert_kind_of MockRegistryTranscriptAdapter, adapter
  end

  test "risky villa has tenants and rights" do
    data = @adapter.fetch_data(case_number: "2026타경10002")
    assert data[:rights].any?
    assert data[:tenants].any?
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/adapters/mock_registry_transcript_adapter_test.rb`
Expected: FAIL — `NameError: uninitialized constant RegistryTranscriptAdapter`

- [ ] **Step 3: Create base adapter**

```ruby
# app/adapters/registry_transcript_adapter.rb
class RegistryTranscriptAdapter
  def self.for
    if ENV["USE_MOCK"] == "false"
      raise NotImplementedError, "Real registry transcript adapter not yet implemented"
    else
      MockRegistryTranscriptAdapter.new
    end
  end

  def fetch_data(case_number:)
    raise NotImplementedError, "#{self.class}#fetch_data must be implemented"
  end
end
```

- [ ] **Step 4: Create mock adapter**

```ruby
# app/adapters/mock_registry_transcript_adapter.rb
class MockRegistryTranscriptAdapter < RegistryTranscriptAdapter
  MOCK_DATA = {
    "2026타경10001" => {
      rights: [
        { type: "근저당", date: "2024-01-15", holder: "국민은행", amount: 216_000_000, status: "active", registry_section: "을구" }
      ],
      tenants: [],
      hug_waiver: false,
      seizures: []
    },
    "2026타경10002" => {
      rights: [
        { type: "근저당", date: "2023-06-01", holder: "신한은행", amount: 180_000_000, status: "active", registry_section: "을구" },
        { type: "가압류", date: "2023-09-15", holder: "채권추심회사", amount: 50_000_000, status: "active", registry_section: "갑구" }
      ],
      tenants: [
        { name: "김임차", deposit: 50_000_000, move_in_date: "2023-03-01", confirmed_date: "2023-03-05", dividend_requested: true, is_small_sum_tenant: false }
      ],
      hug_waiver: false,
      seizures: [
        { type: "압류", date: "2024-01-20", holder: "관할세무서", amount: 8_000_000 }
      ]
    },
    "2026타경10003" => {
      rights: [
        { type: "근저당", date: "2024-05-10", holder: "우리은행", amount: 150_000_000, status: "active", registry_section: "을구" }
      ],
      tenants: [
        { name: "이전세", deposit: 30_000_000, move_in_date: "2024-08-01", confirmed_date: "2024-08-02", dividend_requested: true, is_small_sum_tenant: false }
      ],
      hug_waiver: true,
      seizures: []
    }
  }.freeze

  BANKS = %w[국민은행 신한은행 우리은행 하나은행 농협은행 기업은행 SC제일은행].freeze
  CREDITORS = %w[채권추심회사 자산관리공사 신용보증기금].freeze
  TAX_OFFICES = %w[관할세무서 강남세무서 서초세무서 영등포세무서 마포세무서].freeze
  RIGHT_TYPES = %w[근저당 근저당 근저당 가압류 강제경매개시결정].freeze

  def fetch_data(case_number:)
    MOCK_DATA[case_number] || generate_random_registry(case_number)
  end

  private

  def generate_random_registry(case_number)
    rng = Random.new(case_number.bytes.sum + 42)

    rights = generate_rights(rng)
    base_date = rights.map { |r| Date.parse(r[:date]) }.min
    tenants = generate_tenants(rng, base_date)
    seizures = generate_seizures(rng, base_date)
    hug_waiver = rng.rand < 0.10

    { rights: rights, tenants: tenants, hug_waiver: hug_waiver, seizures: seizures }
  end

  def generate_rights(rng)
    count = rng.rand(1..3)
    base_year = rng.rand(2020..2025)

    count.times.map do |i|
      type = RIGHT_TYPES[rng.rand(RIGHT_TYPES.size)]
      holder = type == "근저당" ? BANKS[rng.rand(BANKS.size)] : CREDITORS[rng.rand(CREDITORS.size)]
      month = rng.rand(1..12)
      day = rng.rand(1..28)
      date = "#{base_year + i}-#{format('%02d', month)}-#{format('%02d', day)}"
      amount = rng.rand(5..30) * 10_000_000

      {
        type: type,
        date: date,
        holder: holder,
        amount: amount,
        status: "active",
        registry_section: type == "근저당" ? "을구" : "갑구"
      }
    end
  end

  def generate_tenants(rng, base_date)
    return [] if rng.rand >= 0.45

    count = rng.rand(1..2)
    count.times.map do |i|
      days_offset = rng.rand(-180..360)
      move_in = base_date + days_offset
      confirmed = move_in + rng.rand(1..14)
      deposit = rng.rand(2..10) * 5_000_000

      {
        name: "임차인#{rng.rand(100..999)}",
        deposit: deposit,
        move_in_date: move_in.to_s,
        confirmed_date: confirmed.to_s,
        dividend_requested: rng.rand < 0.7,
        is_small_sum_tenant: deposit <= 16_500_000
      }
    end
  end

  def generate_seizures(rng, base_date)
    return [] if rng.rand >= 0.30

    days_after = rng.rand(30..365)
    [{
      type: "압류",
      date: (base_date + days_after).to_s,
      holder: TAX_OFFICES[rng.rand(TAX_OFFICES.size)],
      amount: rng.rand(1..20) * 1_000_000
    }]
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/adapters/mock_registry_transcript_adapter_test.rb`
Expected: All 8 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/adapters/registry_transcript_adapter.rb app/adapters/mock_registry_transcript_adapter.rb test/adapters/mock_registry_transcript_adapter_test.rb
git commit -m "feat(f03): add MockRegistryTranscriptAdapter with deterministic random data"
```

---

## Task 4: Integrate Registry Data into PropertyDataSyncService

**Files:**
- Modify: `app/services/property_data_sync_service.rb`
- Modify: `test/services/property_data_sync_service_test.rb` (if exists)

- [ ] **Step 1: Write failing test**

```ruby
# Add to test/services/property_data_sync_service_test.rb (or create if absent)
require "test_helper"

class PropertyDataSyncServiceRegistryTest < ActiveSupport::TestCase
  test "includes registry_transcript in raw_data" do
    property = PropertyDataSyncService.call(case_number: "2026타경10001")
    assert property.raw_data.key?("registry_transcript")
    transcript = property.raw_data["registry_transcript"]
    assert transcript.key?("rights")
    assert transcript.key?("tenants")
    assert transcript.key?("hug_waiver")
    assert transcript.key?("seizures")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/property_data_sync_service_test.rb -n test_includes_registry_transcript_in_raw_data`
Expected: FAIL — no `registry_transcript` key in raw_data.

- [ ] **Step 3: Modify PropertyDataSyncService**

In `app/services/property_data_sync_service.rb`, add the registry transcript fetch inside `#call`:

```ruby
def call
  court_data = CourtAuctionAdapter.for.fetch_data(case_number: @case_number)
  building_data = BuildingLedgerAdapter.for.fetch_data(case_number: @case_number)
  registry_data = RegistryTranscriptAdapter.for.fetch_data(case_number: @case_number)

  return nil unless court_data

  property = Property.find_or_initialize_by(case_number: @case_number)
  property.assign_attributes(
    court_name: court_data[:court_name],
    property_type: court_data[:property_type],
    address: court_data[:address],
    appraisal_price: court_data[:appraisal_price],
    min_bid_price: court_data[:min_bid_price],
    raw_data: {
      court_auction: court_data.deep_stringify_keys,
      building_ledger: building_data&.deep_stringify_keys,
      registry_transcript: registry_data&.deep_stringify_keys
    }
  )
  property.save!
  property
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/property_data_sync_service_test.rb`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/property_data_sync_service.rb test/services/property_data_sync_service_test.rb
git commit -m "feat(f03): integrate registry transcript data into PropertyDataSyncService"
```

---

## Task 5: Service — ExtinguishmentBaseRightExtractor

**Files:**
- Create: `app/services/rights_analysis/extinguishment_base_right_extractor.rb`
- Create: `test/services/rights_analysis/extinguishment_base_right_extractor_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# test/services/rights_analysis/extinguishment_base_right_extractor_test.rb
require "test_helper"

class RightsAnalysis::ExtinguishmentBaseRightExtractorTest < ActiveSupport::TestCase
  test "extracts earliest mortgage as base right" do
    registry_data = {
      "rights" => [
        { "type" => "근저당", "date" => "2024-03-01", "holder" => "우리은행", "amount" => 100_000_000 },
        { "type" => "근저당", "date" => "2024-01-15", "holder" => "국민은행", "amount" => 200_000_000 }
      ]
    }
    result = RightsAnalysis::ExtinguishmentBaseRightExtractor.call(registry_data)

    assert_equal "근저당", result[:type]
    assert_equal Date.parse("2024-01-15"), result[:date]
    assert_equal "국민은행", result[:holder]
  end

  test "extracts provisional seizure as base right when earliest" do
    registry_data = {
      "rights" => [
        { "type" => "가압류", "date" => "2023-06-01", "holder" => "채권추심회사", "amount" => 50_000_000 },
        { "type" => "근저당", "date" => "2024-01-15", "holder" => "국민은행", "amount" => 200_000_000 }
      ]
    }
    result = RightsAnalysis::ExtinguishmentBaseRightExtractor.call(registry_data)

    assert_equal "가압류", result[:type]
    assert_equal Date.parse("2023-06-01"), result[:date]
    assert_equal "채권추심회사", result[:holder]
  end

  test "considers only base-right-eligible types" do
    registry_data = {
      "rights" => [
        { "type" => "전세권", "date" => "2022-01-01", "holder" => "임차인", "amount" => 50_000_000 },
        { "type" => "근저당", "date" => "2024-01-15", "holder" => "국민은행", "amount" => 200_000_000 }
      ]
    }
    result = RightsAnalysis::ExtinguishmentBaseRightExtractor.call(registry_data)

    assert_equal "근저당", result[:type]
    assert_equal Date.parse("2024-01-15"), result[:date]
  end

  test "returns nil when no eligible rights exist" do
    registry_data = { "rights" => [] }
    result = RightsAnalysis::ExtinguishmentBaseRightExtractor.call(registry_data)
    assert_nil result
  end

  test "returns nil when registry data is nil" do
    result = RightsAnalysis::ExtinguishmentBaseRightExtractor.call(nil)
    assert_nil result
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/rights_analysis/extinguishment_base_right_extractor_test.rb`
Expected: FAIL — `NameError: uninitialized constant RightsAnalysis`

- [ ] **Step 3: Implement**

```ruby
# app/services/rights_analysis/extinguishment_base_right_extractor.rb
module RightsAnalysis
  class ExtinguishmentBaseRightExtractor
    ELIGIBLE_TYPES = %w[근저당 가압류 압류 강제경매개시결정].freeze

    def self.call(registry_data)
      return nil if registry_data.nil?

      rights = registry_data["rights"] || []
      eligible = rights.select { |r| ELIGIBLE_TYPES.include?(r["type"]) }
      return nil if eligible.empty?

      earliest = eligible.min_by { |r| Date.parse(r["date"]) }

      {
        type: earliest["type"],
        date: Date.parse(earliest["date"]),
        holder: earliest["holder"],
        amount: earliest["amount"]
      }
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/rights_analysis/extinguishment_base_right_extractor_test.rb`
Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/rights_analysis/extinguishment_base_right_extractor.rb test/services/rights_analysis/extinguishment_base_right_extractor_test.rb
git commit -m "feat(f03): add ExtinguishmentBaseRightExtractor service"
```

---

## Task 6: Service — OpposingPowerDeterminer

**Files:**
- Create: `app/services/rights_analysis/opposing_power_determiner.rb`
- Create: `test/services/rights_analysis/opposing_power_determiner_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# test/services/rights_analysis/opposing_power_determiner_test.rb
require "test_helper"

class RightsAnalysis::OpposingPowerDeterminerTest < ActiveSupport::TestCase
  test "tenant with move-in before base right has opposing power" do
    base_right = { type: "근저당", date: Date.parse("2024-06-01"), holder: "국민은행" }
    registry_data = {
      "tenants" => [
        { "name" => "임차인A", "deposit" => 50_000_000, "move_in_date" => "2024-03-01",
          "confirmed_date" => "2024-03-05", "dividend_requested" => true, "is_small_sum_tenant" => false }
      ]
    }

    result = RightsAnalysis::OpposingPowerDeterminer.call(registry_data, base_right)

    assert_equal 1, result.size
    assert result.first[:has_opposing_power]
  end

  test "tenant with move-in after base right has no opposing power" do
    base_right = { type: "근저당", date: Date.parse("2024-01-15"), holder: "국민은행" }
    registry_data = {
      "tenants" => [
        { "name" => "임차인A", "deposit" => 50_000_000, "move_in_date" => "2024-03-01",
          "confirmed_date" => "2024-03-05", "dividend_requested" => true, "is_small_sum_tenant" => false }
      ]
    }

    result = RightsAnalysis::OpposingPowerDeterminer.call(registry_data, base_right)

    assert_equal 1, result.size
    assert_not result.first[:has_opposing_power]
  end

  test "opposing power uses next-day 00:00 rule" do
    # Move-in on 2024-01-15 → opposing power from 2024-01-16 00:00
    # Base right on 2024-01-16 → base right is NOT before opposing power date
    # So tenant HAS opposing power (opposing power date <= base right date)
    base_right = { type: "근저당", date: Date.parse("2024-01-16"), holder: "은행" }
    registry_data = {
      "tenants" => [
        { "name" => "임차인A", "deposit" => 50_000_000, "move_in_date" => "2024-01-15",
          "confirmed_date" => "2024-01-16", "dividend_requested" => true, "is_small_sum_tenant" => false }
      ]
    }

    result = RightsAnalysis::OpposingPowerDeterminer.call(registry_data, base_right)
    assert result.first[:has_opposing_power]
  end

  test "same-day move-in as base right has no opposing power" do
    # Move-in on 2024-01-15 → opposing power from 2024-01-16
    # Base right on 2024-01-15 → base right date < opposing power date
    # So tenant has NO opposing power
    base_right = { type: "근저당", date: Date.parse("2024-01-15"), holder: "은행" }
    registry_data = {
      "tenants" => [
        { "name" => "임차인A", "deposit" => 50_000_000, "move_in_date" => "2024-01-15",
          "confirmed_date" => "2024-01-16", "dividend_requested" => true, "is_small_sum_tenant" => false }
      ]
    }

    result = RightsAnalysis::OpposingPowerDeterminer.call(registry_data, base_right)
    assert_not result.first[:has_opposing_power]
  end

  test "returns empty array when no tenants" do
    base_right = { type: "근저당", date: Date.parse("2024-01-15"), holder: "은행" }
    registry_data = { "tenants" => [] }

    result = RightsAnalysis::OpposingPowerDeterminer.call(registry_data, base_right)
    assert_empty result
  end

  test "returns tenants with all fields preserved" do
    base_right = { type: "근저당", date: Date.parse("2024-01-15"), holder: "은행" }
    registry_data = {
      "tenants" => [
        { "name" => "임차인A", "deposit" => 50_000_000, "move_in_date" => "2024-03-01",
          "confirmed_date" => "2024-03-05", "dividend_requested" => true, "is_small_sum_tenant" => false }
      ]
    }

    result = RightsAnalysis::OpposingPowerDeterminer.call(registry_data, base_right)
    tenant = result.first
    assert_equal "임차인A", tenant[:name]
    assert_equal 50_000_000, tenant[:deposit]
    assert_equal "2024-03-01", tenant[:move_in_date]
    assert_equal "2024-03-05", tenant[:confirmed_date]
    assert tenant.key?(:has_opposing_power)
  end

  test "returns all tenants as no-opposing-power when base_right is nil" do
    registry_data = {
      "tenants" => [
        { "name" => "임차인A", "deposit" => 50_000_000, "move_in_date" => "2024-03-01",
          "confirmed_date" => "2024-03-05", "dividend_requested" => true, "is_small_sum_tenant" => false }
      ]
    }

    result = RightsAnalysis::OpposingPowerDeterminer.call(registry_data, nil)
    assert_not result.first[:has_opposing_power]
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/rights_analysis/opposing_power_determiner_test.rb`
Expected: FAIL

- [ ] **Step 3: Implement**

```ruby
# app/services/rights_analysis/opposing_power_determiner.rb
module RightsAnalysis
  class OpposingPowerDeterminer
    def self.call(registry_data, base_right)
      return [] if registry_data.nil?

      tenants = registry_data["tenants"] || []
      return [] if tenants.empty?

      tenants.map do |tenant|
        has_power = if base_right.nil?
          false
        else
          # Opposing power starts from the day AFTER move-in (next day 00:00)
          move_in_date = Date.parse(tenant["move_in_date"])
          opposing_power_date = move_in_date + 1
          opposing_power_date <= base_right[:date]
        end

        {
          name: tenant["name"],
          deposit: tenant["deposit"],
          move_in_date: tenant["move_in_date"],
          confirmed_date: tenant["confirmed_date"],
          dividend_requested: tenant["dividend_requested"],
          is_small_sum_tenant: tenant["is_small_sum_tenant"],
          has_opposing_power: has_power
        }
      end
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/rights_analysis/opposing_power_determiner_test.rb`
Expected: All 7 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/rights_analysis/opposing_power_determiner.rb test/services/rights_analysis/opposing_power_determiner_test.rb
git commit -m "feat(f03): add OpposingPowerDeterminer with next-day-00:00 rule"
```

---

## Task 7: Service — AssumedAmountCalculator

**Files:**
- Create: `app/services/rights_analysis/assumed_amount_calculator.rb`
- Create: `test/services/rights_analysis/assumed_amount_calculator_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# test/services/rights_analysis/assumed_amount_calculator_test.rb
require "test_helper"

class RightsAnalysis::AssumedAmountCalculatorTest < ActiveSupport::TestCase
  test "opposing power tenant without dividend request is assumed" do
    tenants = [
      { name: "임차인A", deposit: 50_000_000, has_opposing_power: true,
        dividend_requested: false, confirmed_date: "2024-03-05", is_small_sum_tenant: false }
    ]

    result = RightsAnalysis::AssumedAmountCalculator.call(tenants)

    assert_equal 50_000_000, result[:assumed_amount]
    assert_equal 50_000_000, result[:total_risk_amount]
  end

  test "opposing power tenant with dividend request is not assumed" do
    tenants = [
      { name: "임차인A", deposit: 50_000_000, has_opposing_power: true,
        dividend_requested: true, confirmed_date: "2024-03-05", is_small_sum_tenant: false }
    ]

    result = RightsAnalysis::AssumedAmountCalculator.call(tenants)

    assert_equal 0, result[:assumed_amount]
    assert_equal 0, result[:total_risk_amount]
  end

  test "non-opposing power tenant is never assumed" do
    tenants = [
      { name: "임차인A", deposit: 50_000_000, has_opposing_power: false,
        dividend_requested: false, confirmed_date: "2024-03-05", is_small_sum_tenant: false }
    ]

    result = RightsAnalysis::AssumedAmountCalculator.call(tenants)

    assert_equal 0, result[:assumed_amount]
  end

  test "opposing power without confirmed date adds to risk amount" do
    tenants = [
      { name: "임차인A", deposit: 50_000_000, has_opposing_power: true,
        dividend_requested: true, confirmed_date: nil, is_small_sum_tenant: false }
    ]

    result = RightsAnalysis::AssumedAmountCalculator.call(tenants)

    assert_equal 0, result[:assumed_amount]
    assert_equal 50_000_000, result[:total_risk_amount]
  end

  test "sums multiple assumed tenants" do
    tenants = [
      { name: "임차인A", deposit: 30_000_000, has_opposing_power: true,
        dividend_requested: false, confirmed_date: nil, is_small_sum_tenant: false },
      { name: "임차인B", deposit: 20_000_000, has_opposing_power: true,
        dividend_requested: false, confirmed_date: nil, is_small_sum_tenant: false }
    ]

    result = RightsAnalysis::AssumedAmountCalculator.call(tenants)

    assert_equal 50_000_000, result[:assumed_amount]
  end

  test "empty tenants returns zero" do
    result = RightsAnalysis::AssumedAmountCalculator.call([])
    assert_equal 0, result[:assumed_amount]
    assert_equal 0, result[:total_risk_amount]
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/rights_analysis/assumed_amount_calculator_test.rb`
Expected: FAIL

- [ ] **Step 3: Implement**

```ruby
# app/services/rights_analysis/assumed_amount_calculator.rb
module RightsAnalysis
  class AssumedAmountCalculator
    def self.call(tenants)
      assumed_amount = 0
      total_risk_amount = 0

      tenants.each do |tenant|
        next unless tenant[:has_opposing_power]

        deposit = tenant[:deposit] || 0

        if !tenant[:dividend_requested]
          # Opposing power + no dividend request = bidder must assume full deposit
          assumed_amount += deposit
          total_risk_amount += deposit
        elsif tenant[:confirmed_date].nil?
          # Dividend requested but no confirmed date = uncertain priority, risk
          total_risk_amount += deposit
        end
        # Opposing power + dividend requested + confirmed date = will be resolved through distribution
      end

      { assumed_amount: assumed_amount, total_risk_amount: total_risk_amount }
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/rights_analysis/assumed_amount_calculator_test.rb`
Expected: All 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/rights_analysis/assumed_amount_calculator.rb test/services/rights_analysis/assumed_amount_calculator_test.rb
git commit -m "feat(f03): add AssumedAmountCalculator service"
```

---

## Task 8: Service — DividendSimulator

**Files:**
- Create: `app/services/rights_analysis/dividend_simulator.rb`
- Create: `test/services/rights_analysis/dividend_simulator_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# test/services/rights_analysis/dividend_simulator_test.rb
require "test_helper"

class RightsAnalysis::DividendSimulatorTest < ActiveSupport::TestCase
  test "distributes to auction costs first" do
    rights = [{ "type" => "근저당", "date" => "2024-01-15", "holder" => "국민은행", "amount" => 200_000_000 }]
    tenants = []
    seizures = []

    result = RightsAnalysis::DividendSimulator.call(
      rights: rights, tenants: tenants, seizures: seizures,
      expected_bid: 150_000_000, auction_cost: 3_000_000
    )

    assert_equal 6, result[:distribution].size  # one per priority level (some may be empty)
    costs_row = result[:distribution].find { |d| d[:type] == "경매 비용" }
    assert_equal 3_000_000, costs_row[:dividend]
  end

  test "mortgage receives remainder after costs" do
    rights = [{ "type" => "근저당", "date" => "2024-01-15", "holder" => "국민은행", "amount" => 200_000_000 }]

    result = RightsAnalysis::DividendSimulator.call(
      rights: rights, tenants: [], seizures: [],
      expected_bid: 150_000_000, auction_cost: 3_000_000
    )

    mortgage_row = result[:distribution].find { |d| d[:holder] == "국민은행" }
    assert_equal 147_000_000, mortgage_row[:dividend]
    assert_equal 53_000_000, mortgage_row[:shortfall]
  end

  test "small sum tenant gets priority repayment" do
    rights = [{ "type" => "근저당", "date" => "2024-01-15", "holder" => "국민은행", "amount" => 200_000_000 }]
    tenants = [
      { name: "소액임차인", deposit: 16_500_000, has_opposing_power: true,
        dividend_requested: true, confirmed_date: "2024-03-05", is_small_sum_tenant: true }
    ]

    result = RightsAnalysis::DividendSimulator.call(
      rights: rights, tenants: tenants, seizures: [],
      expected_bid: 150_000_000, auction_cost: 3_000_000
    )

    small_sum_row = result[:distribution].find { |d| d[:holder] == "소액임차인" }
    assert_equal 16_500_000, small_sum_row[:dividend]
  end

  test "bidder burden shows safe when no assumed amount" do
    rights = [{ "type" => "근저당", "date" => "2024-01-15", "holder" => "국민은행", "amount" => 100_000_000 }]

    result = RightsAnalysis::DividendSimulator.call(
      rights: rights, tenants: [], seizures: [],
      expected_bid: 150_000_000, auction_cost: 3_000_000
    )

    assert_equal 0, result[:bidder_burden][:assumed_amount]
    assert_equal "safe", result[:bidder_burden][:verdict]
  end

  test "bidder burden shows danger when assumed amount exists" do
    rights = [{ "type" => "근저당", "date" => "2024-01-15", "holder" => "국민은행", "amount" => 100_000_000 }]
    tenants = [
      { name: "임차인A", deposit: 30_000_000, has_opposing_power: true,
        dividend_requested: false, confirmed_date: nil, is_small_sum_tenant: false }
    ]

    result = RightsAnalysis::DividendSimulator.call(
      rights: rights, tenants: tenants, seizures: [],
      expected_bid: 150_000_000, auction_cost: 3_000_000
    )

    assert_equal 30_000_000, result[:bidder_burden][:assumed_amount]
    assert_equal "danger", result[:bidder_burden][:verdict]
  end

  test "returns nil distribution when expected_bid is nil" do
    result = RightsAnalysis::DividendSimulator.call(
      rights: [], tenants: [], seizures: [],
      expected_bid: nil, auction_cost: 3_000_000
    )

    assert_empty result[:distribution]
    assert_nil result[:expected_bid]
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/rights_analysis/dividend_simulator_test.rb`
Expected: FAIL

- [ ] **Step 3: Implement**

```ruby
# app/services/rights_analysis/dividend_simulator.rb
module RightsAnalysis
  class DividendSimulator
    PRIORITY_ORDER = [
      { priority: 0, label: "경매 비용" },
      { priority: 1, label: "소액임차인 최우선변제" },
      { priority: 2, label: "당해세" },
      { priority: 3, label: "근저당/전세권" },
      { priority: 4, label: "확정일자 임차인" },
      { priority: 5, label: "일반 채권" }
    ].freeze

    def self.call(rights:, tenants:, seizures:, expected_bid:, auction_cost: 3_000_000)
      new(rights:, tenants:, seizures:, expected_bid:, auction_cost:).call
    end

    def initialize(rights:, tenants:, seizures:, expected_bid:, auction_cost:)
      @rights = rights || []
      @tenants = tenants || []
      @seizures = seizures || []
      @expected_bid = expected_bid
      @auction_cost = auction_cost
    end

    def call
      if @expected_bid.nil?
        return {
          expected_bid: nil,
          distribution: [],
          bidder_burden: compute_bidder_burden([])
        }
      end

      remaining = @expected_bid
      distribution = []

      # Priority 0: Auction costs
      cost_dividend = [ @auction_cost, remaining ].min
      distribution << { priority: 0, holder: "경매 비용", type: "경매 비용",
                         claim: @auction_cost, dividend: cost_dividend, shortfall: @auction_cost - cost_dividend }
      remaining -= cost_dividend

      # Priority 1: Small-sum tenant priority repayment
      small_sum = @tenants.select { |t| t[:is_small_sum_tenant] && t[:has_opposing_power] }
      small_sum.each do |tenant|
        claim = tenant[:deposit]
        dividend = [ claim, remaining ].min
        distribution << { priority: 1, holder: tenant[:name], type: "소액임차인",
                           claim: claim, dividend: dividend, shortfall: claim - dividend }
        remaining -= dividend
      end

      # Priority 2: Current-year tax (당해세)
      @seizures.each do |seizure|
        claim = seizure["amount"] || seizure[:amount]
        dividend = [ claim, remaining ].min
        holder = seizure["holder"] || seizure[:holder]
        distribution << { priority: 2, holder: holder, type: "당해세",
                           claim: claim, dividend: dividend, shortfall: claim - dividend }
        remaining -= dividend
      end

      # Priority 3: Mortgages/lease rights by establishment date
      mortgages = @rights
        .select { |r| %w[근저당 전세권].include?(r["type"] || r[:type]) }
        .sort_by { |r| Date.parse(r["date"] || r[:date].to_s) }
      mortgages.each do |right|
        claim = right["amount"] || right[:amount]
        holder = right["holder"] || right[:holder]
        type = right["type"] || right[:type]
        dividend = [ claim, remaining ].min
        distribution << { priority: 3, holder: holder, type: type,
                           claim: claim, dividend: dividend, shortfall: claim - dividend }
        remaining -= dividend
      end

      # Priority 4: Tenants with confirmed date (non-small-sum, with opposing power and dividend request)
      confirmed_tenants = @tenants
        .reject { |t| t[:is_small_sum_tenant] }
        .select { |t| t[:has_opposing_power] && t[:dividend_requested] && t[:confirmed_date] }
        .sort_by { |t| Date.parse(t[:confirmed_date]) }
      confirmed_tenants.each do |tenant|
        claim = tenant[:deposit]
        dividend = [ claim, remaining ].min
        distribution << { priority: 4, holder: tenant[:name], type: "확정일자 임차인",
                           claim: claim, dividend: dividend, shortfall: claim - dividend }
        remaining -= dividend
      end

      # Priority 5: General creditors
      general = @rights.select { |r| %w[가압류 압류 강제경매개시결정].include?(r["type"] || r[:type]) }
      general.each do |right|
        claim = right["amount"] || right[:amount]
        holder = right["holder"] || right[:holder]
        type = right["type"] || right[:type]
        dividend = [ claim, remaining ].min
        distribution << { priority: 5, holder: holder, type: type,
                           claim: claim, dividend: dividend, shortfall: claim - dividend }
        remaining -= dividend
      end

      {
        expected_bid: @expected_bid,
        distribution: distribution,
        bidder_burden: compute_bidder_burden(distribution)
      }
    end

    private

    def compute_bidder_burden(distribution)
      # Assumed amount = opposing power tenants who did NOT request dividend
      assumed = @tenants
        .select { |t| t[:has_opposing_power] && !t[:dividend_requested] }
        .sum { |t| t[:deposit] || 0 }

      # Unconfirmed risk = opposing power tenants with dividend request but no confirmed date
      unconfirmed = @tenants
        .select { |t| t[:has_opposing_power] && t[:dividend_requested] && t[:confirmed_date].nil? }
        .sum { |t| t[:deposit] || 0 }

      total = assumed + unconfirmed
      verdict = if total == 0
        "safe"
      elsif assumed == 0 && unconfirmed > 0
        "caution"
      else
        "danger"
      end

      { assumed_amount: assumed, unconfirmed_risk: unconfirmed, total_burden: total, verdict: verdict }
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/rights_analysis/dividend_simulator_test.rb`
Expected: All 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/rights_analysis/dividend_simulator.rb test/services/rights_analysis/dividend_simulator_test.rb
git commit -m "feat(f03): add DividendSimulator with priority-based distribution"
```

---

## Task 9: Service — OpportunityDetector

**Files:**
- Create: `app/services/rights_analysis/opportunity_detector.rb`
- Create: `test/services/rights_analysis/opportunity_detector_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# test/services/rights_analysis/opportunity_detector_test.rb
require "test_helper"

class RightsAnalysis::OpportunityDetectorTest < ActiveSupport::TestCase
  test "detects HUG waiver opportunity" do
    registry_data = { "hug_waiver" => true }
    tenants = [{ name: "임차인A", deposit: 50_000_000, has_opposing_power: true }]

    result = RightsAnalysis::OpportunityDetector.call(
      registry_data: registry_data, tenants: tenants, check_results: []
    )

    assert_equal "hug_waiver", result[:opportunity_type]
    assert_includes result[:opportunity_reason], "HUG"
  end

  test "detects full-dividend opportunity" do
    registry_data = { "hug_waiver" => false }
    tenants = [
      { name: "임차인A", deposit: 50_000_000, has_opposing_power: true,
        dividend_requested: true, confirmed_date: "2024-03-05", estimated_dividend: 50_000_000 }
    ]

    result = RightsAnalysis::OpportunityDetector.call(
      registry_data: registry_data, tenants: tenants, check_results: []
    )

    assert_equal "full_dividend", result[:opportunity_type]
    assert_includes result[:opportunity_reason], "배당"
  end

  test "returns nil when no opportunity" do
    registry_data = { "hug_waiver" => false }
    tenants = [
      { name: "임차인A", deposit: 50_000_000, has_opposing_power: true,
        dividend_requested: false, confirmed_date: nil }
    ]

    result = RightsAnalysis::OpportunityDetector.call(
      registry_data: registry_data, tenants: tenants, check_results: []
    )

    assert_nil result[:opportunity_type]
  end

  test "returns nil when no tenants and no HUG" do
    registry_data = { "hug_waiver" => false }

    result = RightsAnalysis::OpportunityDetector.call(
      registry_data: registry_data, tenants: [], check_results: []
    )

    assert_nil result[:opportunity_type]
  end

  test "HUG waiver takes priority over full-dividend" do
    registry_data = { "hug_waiver" => true }
    tenants = [
      { name: "임차인A", deposit: 50_000_000, has_opposing_power: true,
        dividend_requested: true, confirmed_date: "2024-03-05", estimated_dividend: 50_000_000 }
    ]

    result = RightsAnalysis::OpportunityDetector.call(
      registry_data: registry_data, tenants: tenants, check_results: []
    )

    assert_equal "hug_waiver", result[:opportunity_type]
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/rights_analysis/opportunity_detector_test.rb`
Expected: FAIL

- [ ] **Step 3: Implement**

```ruby
# app/services/rights_analysis/opportunity_detector.rb
module RightsAnalysis
  class OpportunityDetector
    def self.call(registry_data:, tenants:, check_results:)
      new(registry_data:, tenants:, check_results:).call
    end

    def initialize(registry_data:, tenants:, check_results:)
      @registry_data = registry_data || {}
      @tenants = tenants || []
      @check_results = check_results || []
    end

    def call
      return hug_waiver_opportunity if hug_waiver?
      return full_dividend_opportunity if full_dividend?

      { opportunity_type: nil, opportunity_reason: nil }
    end

    private

    def hug_waiver?
      @registry_data["hug_waiver"] == true
    end

    def full_dividend?
      opposing_tenants = @tenants.select { |t| t[:has_opposing_power] }
      return false if opposing_tenants.empty?

      opposing_tenants.all? do |t|
        t[:dividend_requested] && t[:confirmed_date] && t[:estimated_dividend] && t[:estimated_dividend] >= (t[:deposit] || 0)
      end
    end

    def hug_waiver_opportunity
      {
        opportunity_type: "hug_waiver",
        opportunity_reason: "HUG(주택도시보증공사)가 대항력을 포기하여, 임차인 보증금 인수 부담이 없습니다."
      }
    end

    def full_dividend_opportunity
      {
        opportunity_type: "full_dividend",
        opportunity_reason: "대항력 있는 임차인이 배당을 통해 보증금 전액을 회수할 수 있어, 낙찰자의 실질 인수 부담이 없습니다."
      }
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/rights_analysis/opportunity_detector_test.rb`
Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/rights_analysis/opportunity_detector.rb test/services/rights_analysis/opportunity_detector_test.rb
git commit -m "feat(f03): add OpportunityDetector for HUG waiver and full-dividend detection"
```

---

## Task 10: Service — RightsAnalysisService (Orchestrator)

**Files:**
- Create: `app/services/rights_analysis_service.rb`
- Create: `test/services/rights_analysis_service_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# test/services/rights_analysis_service_test.rb
require "test_helper"

class RightsAnalysisServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
    @safe_property = PropertyDataSyncService.call(case_number: "2026타경10001")
    @risky_property = PropertyDataSyncService.call(case_number: "2026타경10002")
  end

  test "creates a RightsAnalysisReport for safe property" do
    assert_difference "RightsAnalysisReport.count", 1 do
      RightsAnalysisService.call(property: @safe_property, user: @user)
    end

    report = RightsAnalysisReport.find_by(property: @safe_property, user: @user)
    assert_not_nil report
    assert_equal "근저당", report.base_right_type
    assert report.safe?
    assert_not_nil report.analyzed_at
  end

  test "creates a report for risky property with assumed amount" do
    RightsAnalysisService.call(property: @risky_property, user: @user)

    report = RightsAnalysisReport.find_by(property: @risky_property, user: @user)
    assert_not_nil report
    assert report.assumed_amount > 0 || report.total_risk_amount > 0
  end

  test "populates report_data with timeline and tenants" do
    RightsAnalysisService.call(property: @risky_property, user: @user)

    report = RightsAnalysisReport.find_by(property: @risky_property, user: @user)
    data = report.report_data
    assert data.key?("registry_timeline")
    assert data.key?("tenants")
    assert data.key?("dividend_simulation")
    assert data.key?("bidder_burden")
    assert data.key?("checklist_references")
  end

  test "upserts on re-analysis" do
    RightsAnalysisService.call(property: @safe_property, user: @user)

    assert_no_difference "RightsAnalysisReport.count" do
      RightsAnalysisService.call(property: @safe_property, user: @user)
    end
  end

  test "detects HUG opportunity for officetel mock" do
    hug_property = PropertyDataSyncService.call(case_number: "2026타경10003")
    RightsAnalysisService.call(property: hug_property, user: @user)

    report = RightsAnalysisReport.find_by(property: hug_property, user: @user)
    assert_equal "hug_waiver", report.opportunity_type
  end

  test "returns the report" do
    result = RightsAnalysisService.call(property: @safe_property, user: @user)
    assert_kind_of RightsAnalysisReport, result
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/rights_analysis_service_test.rb`
Expected: FAIL

- [ ] **Step 3: Implement**

```ruby
# app/services/rights_analysis_service.rb
class RightsAnalysisService
  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    registry_data = @property.raw_data&.dig("registry_transcript")
    check_results = @property.property_check_results.where(user: @user).includes(:checklist_item)

    # Step 1: Extract base right
    base_right = RightsAnalysis::ExtinguishmentBaseRightExtractor.call(registry_data)

    # Step 2: Determine opposing power
    tenants = RightsAnalysis::OpposingPowerDeterminer.call(registry_data, base_right)

    # Step 3: Calculate assumed amount
    assumed = RightsAnalysis::AssumedAmountCalculator.call(tenants)

    # Step 4: Detect opportunities
    opportunity = RightsAnalysis::OpportunityDetector.call(
      registry_data: registry_data, tenants: tenants, check_results: check_results
    )

    # Step 5: Build report data
    timeline = build_timeline(registry_data)
    checklist_refs = find_checklist_references(check_results)
    verdict, summary = compute_verdict(base_right, tenants, assumed, check_results)

    # Step 6: Persist
    report = RightsAnalysisReport.find_or_initialize_by(user: @user, property: @property)
    report.assign_attributes(
      base_right_type: base_right&.dig(:type),
      base_right_date: base_right&.dig(:date),
      base_right_holder: base_right&.dig(:holder),
      assumed_amount: assumed[:assumed_amount],
      total_risk_amount: assumed[:total_risk_amount],
      verdict: verdict,
      verdict_summary: summary,
      opportunity_type: opportunity[:opportunity_type],
      opportunity_reason: opportunity[:opportunity_reason],
      analyzed_at: Time.current,
      report_data: {
        registry_timeline: timeline,
        tenants: tenants,
        dividend_simulation: { expected_bid: nil, distribution: [] },
        bidder_burden: { assumed_amount: assumed[:assumed_amount], unconfirmed_risk: assumed[:total_risk_amount] - assumed[:assumed_amount], total_burden: assumed[:total_risk_amount], verdict: verdict.to_s },
        checklist_references: checklist_refs
      }
    )
    report.save!
    report
  end

  private

  def build_timeline(registry_data)
    return [] if registry_data.nil?

    rights = (registry_data["rights"] || []).map do |r|
      { date: r["date"], type: r["type"], holder: r["holder"], amount: r["amount"], registry_section: r["registry_section"] }
    end

    seizures = (registry_data["seizures"] || []).map do |s|
      { date: s["date"], type: s["type"], holder: s["holder"], amount: s["amount"], registry_section: "갑구" }
    end

    (rights + seizures).sort_by { |e| Date.parse(e[:date]) }
  end

  def find_checklist_references(check_results)
    relevant_codes = %w[rights-003 rights-006 rights-009 rights-011]
    check_results
      .select { |r| relevant_codes.include?(r.checklist_item.code) && r.has_risk == true }
      .map { |r| r.checklist_item.code }
  end

  def compute_verdict(base_right, tenants, assumed, check_results)
    has_lien = check_results.any? { |r| r.checklist_item.code == "rights-011" && r.has_risk == true }

    verdict = if has_lien || assumed[:assumed_amount] > 0
      :danger
    elsif assumed[:total_risk_amount] > 0
      :caution
    else
      :safe
    end

    lines = []
    if base_right
      lines << "말소기준권리: #{base_right[:type]} (#{base_right[:date]}, #{base_right[:holder]})"
    else
      lines << "말소기준권리: 해당 없음"
    end

    opposing = tenants.select { |t| t[:has_opposing_power] }
    if opposing.any?
      lines << "대항력 있는 임차인 #{opposing.size}명 — 인수 금액 #{format_amount(assumed[:assumed_amount])}"
    else
      lines << tenants.any? ? "임차인 #{tenants.size}명 — 대항력 없음, 인수 금액 0원" : "임차인 없음"
    end

    lines << "유치권 신고 있음" if has_lien

    [ verdict, lines.join("\n") ]
  end

  def format_amount(amount)
    if amount >= 100_000_000
      "#{amount / 100_000_000}억#{amount % 100_000_000 > 0 ? " #{(amount % 100_000_000).to_fs(:delimited)}원" : "원"}"
    else
      "#{amount.to_fs(:delimited)}원"
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/rights_analysis_service_test.rb`
Expected: All 6 tests PASS.

- [ ] **Step 5: Run all service tests**

Run: `bin/rails test test/services/`
Expected: All tests PASS (no regressions).

- [ ] **Step 6: Commit**

```bash
git add app/services/rights_analysis_service.rb test/services/rights_analysis_service_test.rb
git commit -m "feat(f03): add RightsAnalysisService orchestrator"
```

---

## Task 11: Routes + Controller Rename (results → checklists)

**Files:**
- Create: `app/controllers/analyses/checklists_controller.rb`
- Create: `app/views/analyses/checklists/edit.html.erb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Create checklists controller (copy from results)**

```ruby
# app/controllers/analyses/checklists_controller.rb
module Analyses
  class ChecklistsController < ApplicationController
    def edit
      @property = Property.find(params[:property_id])
      @results_by_axis = @property.property_check_results
        .where(user: current_user)
        .includes(:checklist_item)
        .order("checklist_items.position")
        .group_by { |r| r.checklist_item.risk_axis }
    end

    def update
      @property = Property.find(params[:property_id])

      if params[:resolutions].present?
        params[:resolutions].each do |id, values|
          result = @property.property_check_results.where(user: current_user).find(id)

          if result.source_type == "auto"
            result.update!(
              resolvable: values[:resolvable] == "true",
              resolution_note: values[:resolution_note]
            )
          else
            has_risk = values[:has_risk] == "true"
            attrs = { source_type: "manual", has_risk: has_risk }

            if has_risk
              attrs[:resolvable] = values[:resolvable] == "true"
              attrs[:resolution_note] = values[:resolution_note]
            else
              attrs[:resolvable] = nil
              attrs[:resolution_note] = nil
            end

            result.update!(attrs)
          end
        end
      end

      redirect_to property_analyses_rating_url(@property)
    end
  end
end
```

- [ ] **Step 2: Copy view**

Copy `app/views/analyses/results/edit.html.erb` to `app/views/analyses/checklists/edit.html.erb`. Update the form URL inside:

Change `property_analyses_result_path` to `property_analyses_checklist_path`.

- [ ] **Step 3: Update routes**

```ruby
# config/routes.rb — replace the analyses namespace block:
resources :properties, only: [ :index, :show, :create ] do
  namespace :analyses do
    resource :start, only: [ :create ], controller: "start"
    resource :checklist, only: [ :edit, :update ], controller: "checklists"
    resource :report, only: [ :show, :update ], controller: "reports"
    resource :rating, only: [ :show ], controller: "ratings"
  end
end
```

- [ ] **Step 4: Update StartController redirect**

In `app/controllers/analyses/start_controller.rb`, change:
```ruby
redirect_to edit_property_analyses_result_url(@property)
```
to:
```ruby
redirect_to edit_property_analyses_checklist_url(@property)
```

- [ ] **Step 5: Run existing tests to check for regressions**

Run: `bin/rails test`
Expected: Some tests may fail due to route name changes. Fix any references to old route names (`property_analyses_result_path` → `property_analyses_checklist_path`).

- [ ] **Step 6: Fix broken test references**

Update any test files referencing old route names. Common locations:
- `test/controllers/analyses/results_controller_test.rb` → rename or update
- `test/integration/property_analysis_flow_test.rb` → update route references

- [ ] **Step 7: Verify all tests pass**

Run: `bin/rails test`
Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
git add app/controllers/analyses/checklists_controller.rb app/views/analyses/checklists/ config/routes.rb app/controllers/analyses/start_controller.rb
git add -u  # pick up any renamed/moved files
git commit -m "refactor(f03): rename results to checklists, add report route"
```

---

## Task 12: Controller — ReportsController

**Files:**
- Create: `app/controllers/analyses/reports_controller.rb`
- Create: `test/controllers/analyses/reports_controller_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# test/controllers/analyses/reports_controller_test.rb
require "test_helper"

class Analyses::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:guest)
    @property = properties(:safe_apartment)
    # Ensure user is logged in (guest auto-login)
    get properties_url
  end

  test "show redirects to property when no report exists" do
    get property_analyses_report_url(@property)
    assert_response :redirect
  end

  test "show renders report when exists" do
    RightsAnalysisReport.create!(
      user: @user, property: @property, verdict: :safe,
      analyzed_at: Time.current, assumed_amount: 0, total_risk_amount: 0,
      report_data: { registry_timeline: [], tenants: [], dividend_simulation: { expected_bid: nil, distribution: [] }, bidder_burden: { assumed_amount: 0, unconfirmed_risk: 0, total_burden: 0, verdict: "safe" }, checklist_references: [] }
    )

    get property_analyses_report_url(@property)
    assert_response :success
  end

  test "update runs dividend simulation with expected bid" do
    report = RightsAnalysisReport.create!(
      user: @user, property: @property, verdict: :safe,
      analyzed_at: Time.current, assumed_amount: 0, total_risk_amount: 0,
      report_data: { registry_timeline: [], tenants: [], dividend_simulation: { expected_bid: nil, distribution: [] }, bidder_burden: { assumed_amount: 0, unconfirmed_risk: 0, total_burden: 0, verdict: "safe" }, checklist_references: [] }
    )

    patch property_analyses_report_url(@property), params: { expected_bid: 150_000_000 }
    assert_response :redirect

    report.reload
    assert_equal 150_000_000, report.report_data.dig("dividend_simulation", "expected_bid")
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/analyses/reports_controller_test.rb`
Expected: FAIL

- [ ] **Step 3: Implement controller**

```ruby
# app/controllers/analyses/reports_controller.rb
module Analyses
  class ReportsController < ApplicationController
    def show
      @property = Property.find(params[:property_id])
      @report = RightsAnalysisReport.find_by(property: @property, user: current_user)

      unless @report
        redirect_to property_url(@property), alert: "권리 분석을 먼저 실행해주세요."
        return
      end
    end

    def update
      @property = Property.find(params[:property_id])
      @report = RightsAnalysisReport.find_by!(property: @property, user: current_user)

      expected_bid = params[:expected_bid]&.to_i
      registry_data = @property.raw_data&.dig("registry_transcript")
      tenants = @report.report_data["tenants"]&.map(&:symbolize_keys) || []
      seizures = (registry_data&.dig("seizures") || [])

      rights = (registry_data&.dig("rights") || [])

      simulation = RightsAnalysis::DividendSimulator.call(
        rights: rights, tenants: tenants, seizures: seizures,
        expected_bid: expected_bid
      )

      report_data = @report.report_data.dup
      report_data["dividend_simulation"] = simulation.slice(:expected_bid, :distribution).deep_stringify_keys
      report_data["bidder_burden"] = simulation[:bidder_burden].deep_stringify_keys
      @report.update!(report_data: report_data)

      redirect_to property_analyses_report_url(@property)
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/analyses/reports_controller_test.rb`
Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/analyses/reports_controller.rb test/controllers/analyses/reports_controller_test.rb
git commit -m "feat(f03): add ReportsController with show and dividend simulation update"
```

---

## Task 13: Integrate RightsAnalysisService into StartController

**Files:**
- Modify: `app/controllers/analyses/start_controller.rb`

- [ ] **Step 1: Update StartController**

```ruby
# app/controllers/analyses/start_controller.rb
module Analyses
  class StartController < ApplicationController
    def create
      @property = Property.find(params[:property_id])
      PropertyAnalysisService.call(property: @property, user: current_user)
      RightsAnalysisService.call(property: @property, user: current_user)
      redirect_to edit_property_analyses_checklist_url(@property)
    end
  end
end
```

- [ ] **Step 2: Run all tests**

Run: `bin/rails test`
Expected: All tests PASS.

- [ ] **Step 3: Commit**

```bash
git add app/controllers/analyses/start_controller.rb
git commit -m "feat(f03): run RightsAnalysisService alongside checklist analysis on start"
```

---

## Task 14: ViewComponents — PropertyTabsComponent

**Files:**
- Create: `app/components/property_tabs_component.rb`
- Create: `app/components/property_tabs_component.html.erb`
- Create: `test/components/property_tabs_component_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# test/components/property_tabs_component_test.rb
require "test_helper"

class PropertyTabsComponentTest < ViewComponent::TestCase
  setup do
    @user = users(:guest)
    @property = properties(:safe_apartment)
  end

  test "renders all 4 tabs with numbers" do
    render_inline(PropertyTabsComponent.new(property: @property, user: @user, active_tab: :info))
    assert_text "① 기본 정보"
    assert_text "② 체크리스트"
    assert_text "③ 권리 분석"
    assert_text "④ 등급 산정"
  end

  test "highlights active tab" do
    render_inline(PropertyTabsComponent.new(property: @property, user: @user, active_tab: :report))
    assert_selector "[data-active='true']", text: "③ 권리 분석"
  end

  test "shows checkmark for completed checklist tab" do
    UserProperty.create!(user: @user, property: @property, safety_rating: :safe, analyzed_at: Time.current)
    render_inline(PropertyTabsComponent.new(property: @property, user: @user, active_tab: :info))
    assert_selector "[data-tab='checklist'] [data-completed]"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/components/property_tabs_component_test.rb`
Expected: FAIL

- [ ] **Step 3: Implement component**

```ruby
# app/components/property_tabs_component.rb
class PropertyTabsComponent < ViewComponent::Base
  TABS = [
    { key: :info, number: "①", label: "기본 정보" },
    { key: :checklist, number: "②", label: "체크리스트" },
    { key: :report, number: "③", label: "권리 분석" },
    { key: :rating, number: "④", label: "등급 산정" }
  ].freeze

  def initialize(property:, user:, active_tab:)
    @property = property
    @user = user
    @active_tab = active_tab
  end

  private

  def tabs
    TABS.map do |tab|
      tab.merge(
        active: tab[:key] == @active_tab,
        completed: tab_completed?(tab[:key]),
        url: tab_url(tab[:key])
      )
    end
  end

  def tab_completed?(key)
    case key
    when :info then true
    when :checklist then user_property&.analyzed_at.present?
    when :report then report.present?
    when :rating then user_property&.safety_rating.present?
    end
  end

  def tab_url(key)
    case key
    when :info then helpers.property_path(@property)
    when :checklist then helpers.edit_property_analyses_checklist_path(@property)
    when :report then helpers.property_analyses_report_path(@property)
    when :rating then helpers.property_analyses_rating_path(@property)
    end
  end

  def user_property
    @user_property ||= UserProperty.find_by(user: @user, property: @property)
  end

  def report
    @report ||= RightsAnalysisReport.find_by(user: @user, property: @property)
  end
end
```

```erb
<%# app/components/property_tabs_component.html.erb %>
<nav class="flex border-b border-slate-200 dark:border-slate-700 mb-6" data-controller="property-tabs">
  <% tabs.each do |tab| %>
    <%= link_to tab[:url],
        class: "flex items-center gap-1.5 px-4 py-3 text-sm font-medium border-b-2 -mb-px transition-colors #{tab[:active] ? 'border-blue-600 text-blue-600 dark:border-blue-400 dark:text-blue-400' : 'border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300 hover:border-slate-300'}",
        data: { tab: tab[:key], active: tab[:active], turbo_frame: "tab_content" } do %>
      <span><%= tab[:number] %> <%= tab[:label] %></span>
      <% if tab[:completed] && !tab[:active] %>
        <span data-completed class="text-green-500 dark:text-green-400 text-xs">✓</span>
      <% end %>
    <% end %>
  <% end %>
</nav>
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/components/property_tabs_component_test.rb`
Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/components/property_tabs_component.rb app/components/property_tabs_component.html.erb test/components/property_tabs_component_test.rb
git commit -m "feat(f03): add PropertyTabsComponent with numbered tab navigation"
```

---

## Task 15: ViewComponents — Report Section Components

**Files:**
- Create: `app/components/report_summary_component.rb` + `.html.erb`
- Create: `app/components/registry_timeline_component.rb` + `.html.erb`
- Create: `app/components/dividend_simulator_component.rb` + `.html.erb`
- Create: `app/components/source_doc_viewer_component.rb` + `.html.erb`
- Create: `app/components/legal_disclaimer_component.rb` + `.html.erb`
- Create: `test/components/report_summary_component_test.rb`
- Create: `test/components/registry_timeline_component_test.rb`
- Create: `test/components/dividend_simulator_component_test.rb`

This task creates all report section components. Due to size, tests focus on the core rendering behavior.

- [ ] **Step 1: Write failing tests for ReportSummaryComponent**

```ruby
# test/components/report_summary_component_test.rb
require "test_helper"

class ReportSummaryComponentTest < ViewComponent::TestCase
  test "renders safe verdict" do
    report = rights_analysis_reports(:safe_apartment_report)
    render_inline(ReportSummaryComponent.new(report: report))
    assert_text "안전"
    assert_text "말소기준권리"
  end

  test "renders danger verdict" do
    report = rights_analysis_reports(:risky_villa_report)
    render_inline(ReportSummaryComponent.new(report: report))
    assert_text "위험"
  end

  test "renders opportunity badge when present" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.opportunity_type = "hug_waiver"
    report.opportunity_reason = "HUG가 대항력을 포기"
    render_inline(ReportSummaryComponent.new(report: report))
    assert_text "안전 기회 물건"
  end

  test "renders assumed amount" do
    report = rights_analysis_reports(:safe_apartment_report)
    render_inline(ReportSummaryComponent.new(report: report))
    assert_text "인수 금액"
  end
end
```

- [ ] **Step 2: Write failing tests for other components**

```ruby
# test/components/registry_timeline_component_test.rb
require "test_helper"

class RegistryTimelineComponentTest < ViewComponent::TestCase
  test "renders timeline entries" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "registry_timeline" => [
        { "date" => "2024-01-15", "type" => "근저당", "holder" => "국민은행", "amount" => 200_000_000 }
      ],
      "tenants" => [],
      "checklist_references" => []
    }
    render_inline(RegistryTimelineComponent.new(report: report))
    assert_text "국민은행"
    assert_text "근저당"
  end

  test "renders empty state when no timeline" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = { "registry_timeline" => [], "tenants" => [], "checklist_references" => [] }
    render_inline(RegistryTimelineComponent.new(report: report))
    assert_text "등기부"
  end
end
```

```ruby
# test/components/dividend_simulator_component_test.rb
require "test_helper"

class DividendSimulatorComponentTest < ViewComponent::TestCase
  test "renders bid input form" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(DividendSimulatorComponent.new(report: report, property: property))
    assert_selector "input[name='expected_bid']"
    assert_text "예상 낙찰가"
  end

  test "renders distribution table when simulation exists" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    report.report_data["dividend_simulation"] = {
      "expected_bid" => 150_000_000,
      "distribution" => [
        { "priority" => 0, "holder" => "경매 비용", "type" => "경매 비용", "claim" => 3_000_000, "dividend" => 3_000_000, "shortfall" => 0 }
      ]
    }
    render_inline(DividendSimulatorComponent.new(report: report, property: property))
    assert_text "경매 비용"
  end

  test "renders bidder burden summary" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(DividendSimulatorComponent.new(report: report, property: property))
    assert_text "낙찰자 부담 분석"
  end
end
```

- [ ] **Step 2b: Write failing tests for SourceDocViewerComponent**

```ruby
# test/components/source_doc_viewer_component_test.rb
require "test_helper"

class SourceDocViewerComponentTest < ViewComponent::TestCase
  test "renders court auction data" do
    property = properties(:safe_apartment)
    property.raw_data = { "court_auction" => { "remarks" => "해당사항 없음", "lien_reported" => false }, "registry_transcript" => {} }
    render_inline(SourceDocViewerComponent.new(property: property))
    assert_text "매각물건명세서"
    assert_text "해당사항 없음"
  end

  test "renders registry transcript data" do
    property = properties(:safe_apartment)
    property.raw_data = { "court_auction" => {}, "registry_transcript" => { "rights" => [{ "type" => "근저당" }], "tenants" => [], "hug_waiver" => false, "seizures" => [] } }
    render_inline(SourceDocViewerComponent.new(property: property))
    assert_text "등기부등본"
    assert_text "1건"
  end

  test "renders disclaimer" do
    property = properties(:safe_apartment)
    render_inline(SourceDocViewerComponent.new(property: property))
    assert_text "매각물건명세서 비고란을 직접 확인하세요"
  end
end
```

- [ ] **Step 3: Run all component tests to verify they fail**

Run: `bin/rails test test/components/report_summary_component_test.rb test/components/registry_timeline_component_test.rb test/components/dividend_simulator_component_test.rb test/components/source_doc_viewer_component_test.rb`
Expected: FAIL

- [ ] **Step 4: Implement ReportSummaryComponent**

```ruby
# app/components/report_summary_component.rb
class ReportSummaryComponent < ViewComponent::Base
  VERDICT_CONFIG = {
    "safe" => { color: "text-green-700 dark:text-green-400", bg: "bg-green-50 dark:bg-green-900/20", border: "border-green-300", emoji: "🟢", label: "안전" },
    "caution" => { color: "text-yellow-700 dark:text-yellow-400", bg: "bg-yellow-50 dark:bg-yellow-900/20", border: "border-yellow-300", emoji: "🟡", label: "주의" },
    "danger" => { color: "text-red-700 dark:text-red-400", bg: "bg-red-50 dark:bg-red-900/20", border: "border-red-300", emoji: "🔴", label: "위험" }
  }.freeze

  def initialize(report:)
    @report = report
    @config = VERDICT_CONFIG[report.verdict] || VERDICT_CONFIG["safe"]
  end

  private

  def opportunity?
    @report.opportunity_type.present?
  end

  def format_amount(amount)
    return "0원" if amount.nil? || amount == 0
    amount.to_fs(:delimited) + "원"
  end
end
```

```erb
<%# app/components/report_summary_component.html.erb %>
<div class="rounded-xl border-2 p-6 <%= @config[:border] %> <%= @config[:bg] %>">
  <div class="flex items-start gap-6">
    <div class="text-center shrink-0">
      <div class="text-4xl"><%= @config[:emoji] %></div>
      <div class="text-xl font-bold mt-1 <%= @config[:color] %>"><%= @config[:label] %></div>
      <div class="text-xs text-slate-500 dark:text-slate-400 mt-1">권리 분석 판정</div>
    </div>
    <div class="flex-1 min-w-0">
      <div class="text-sm font-semibold text-slate-900 dark:text-slate-100 mb-2">핵심 근거</div>
      <div class="text-sm text-slate-700 dark:text-slate-300 whitespace-pre-line leading-relaxed"><%= @report.verdict_summary %></div>
    </div>
    <div class="shrink-0 text-center rounded-lg bg-white/60 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700 p-4">
      <div class="text-xs text-slate-500 dark:text-slate-400">인수 금액</div>
      <div class="text-xl font-bold text-slate-900 dark:text-slate-100 mt-1"><%= format_amount(@report.assumed_amount) %></div>
      <div class="text-xs text-slate-500 dark:text-slate-400 mt-2">총 위험 금액</div>
      <div class="text-base font-semibold text-slate-900 dark:text-slate-100"><%= format_amount(@report.total_risk_amount) %></div>
    </div>
  </div>

  <% if opportunity? %>
    <div class="mt-4 flex items-center gap-2 rounded-lg bg-amber-50 dark:bg-amber-900/20 border border-amber-300 dark:border-amber-600 px-4 py-3">
      <span class="text-lg">💡</span>
      <div class="flex-1">
        <div class="text-sm font-semibold text-amber-800 dark:text-amber-200">안전 기회 물건</div>
        <div class="text-xs text-amber-700 dark:text-amber-300"><%= @report.opportunity_reason %></div>
      </div>
      <span class="text-xs text-amber-600 dark:text-amber-400 bg-amber-100 dark:bg-amber-900/40 px-2 py-1 rounded">⚠️ 추정치</span>
    </div>
  <% end %>

  <div class="mt-4 text-xs text-slate-500 dark:text-slate-400">
    본 분석은 AI가 생성한 참고 자료이며, 법적 효력이 없습니다. 투자 판단에 따른 책임은 이용자 본인에게 있습니다.
  </div>
</div>
```

- [ ] **Step 5: Implement RegistryTimelineComponent**

```ruby
# app/components/registry_timeline_component.rb
class RegistryTimelineComponent < ViewComponent::Base
  def initialize(report:)
    @report = report
    @timeline = report.report_data&.dig("registry_timeline") || []
    @tenants = report.report_data&.dig("tenants") || []
    @checklist_refs = report.report_data&.dig("checklist_references") || []
  end

  private

  def base_right_date
    @report.base_right_date
  end

  def format_amount(amount)
    return "—" if amount.nil?
    amount.to_fs(:delimited) + "원"
  end
end
```

```erb
<%# app/components/registry_timeline_component.html.erb %>
<div class="space-y-4">
  <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100">등기부 타임라인</h3>

  <% if @timeline.any? || @tenants.any? %>
    <div class="relative pl-6 border-l-2 border-slate-200 dark:border-slate-700 ml-2 space-y-4">
      <% @timeline.each do |entry| %>
        <% is_base = entry["date"] == @report.base_right_date&.to_s %>
        <div class="relative">
          <div class="absolute -left-[25px] top-1 w-4 h-4 rounded-full border-2 border-white dark:border-slate-900 <%= is_base ? 'bg-red-500' : 'bg-slate-400' %>"></div>
          <div class="rounded-lg border p-3 <%= is_base ? 'border-red-300 bg-red-50 dark:border-red-600 dark:bg-red-900/20' : 'border-slate-200 bg-slate-50 dark:border-slate-700 dark:bg-slate-800/50' %>">
            <div class="flex items-center justify-between">
              <div class="text-sm">
                <% if is_base %><span class="text-xs font-bold text-red-600 dark:text-red-400">★ 말소기준권리</span> <% end %>
                <span class="font-semibold text-slate-900 dark:text-slate-100"><%= entry["type"] %> — <%= entry["holder"] %></span>
              </div>
              <span class="text-xs text-slate-500 dark:text-slate-400"><%= entry["date"] %></span>
            </div>
            <div class="text-xs text-slate-500 dark:text-slate-400 mt-1">채권액: <%= format_amount(entry["amount"]) %></div>
          </div>
        </div>
      <% end %>

      <% @tenants.each do |tenant| %>
        <% has_power = tenant["has_opposing_power"] %>
        <div class="relative">
          <div class="absolute -left-[25px] top-1 w-4 h-4 rounded-full border-2 border-white dark:border-slate-900 <%= has_power ? 'bg-red-500' : 'bg-green-500' %>"></div>
          <div class="rounded-lg border p-3 <%= has_power ? 'border-red-300 bg-red-50 dark:border-red-600 dark:bg-red-900/20' : 'border-green-300 bg-green-50 dark:border-green-600 dark:bg-green-900/20' %>">
            <div class="flex items-center justify-between">
              <div class="text-sm">
                <span class="font-semibold text-slate-900 dark:text-slate-100"><%= tenant["name"] %> — 전입신고</span>
                <span class="ml-2 text-xs px-1.5 py-0.5 rounded <%= has_power ? 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300' : 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300' %>">
                  대항력 <%= has_power ? '있음' : '없음' %>
                </span>
              </div>
              <span class="text-xs text-slate-500 dark:text-slate-400"><%= tenant["move_in_date"] %></span>
            </div>
            <div class="text-xs text-slate-500 dark:text-slate-400 mt-1">
              보증금: <%= format_amount(tenant["deposit"]) %> · 확정일자: <%= tenant["confirmed_date"] || "없음" %> · 배당요구: <%= tenant["dividend_requested"] ? "✓" : "✗" %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
  <% else %>
    <p class="text-sm text-slate-500 dark:text-slate-400">등기부 데이터가 없습니다.</p>
  <% end %>

  <% if @checklist_refs.any? %>
    <div class="mt-3 rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 px-3 py-2 text-xs text-slate-500 dark:text-slate-400">
      📋 연관 체크리스트: <%= @checklist_refs.join(", ") %> — ②체크리스트 탭에서 확인됨
    </div>
  <% end %>
</div>
```

- [ ] **Step 6: Implement DividendSimulatorComponent**

```ruby
# app/components/dividend_simulator_component.rb
class DividendSimulatorComponent < ViewComponent::Base
  BURDEN_CONFIG = {
    "safe" => { color: "text-green-700 dark:text-green-400", bg: "bg-green-50 dark:bg-green-900/20", message: "추가 인수 부담이 없는 구조입니다" },
    "caution" => { color: "text-yellow-700 dark:text-yellow-400", bg: "bg-yellow-50 dark:bg-yellow-900/20", message: "미확인 위험 금액이 존재합니다. 확인이 필요합니다" },
    "danger" => { color: "text-red-700 dark:text-red-400", bg: "bg-red-50 dark:bg-red-900/20", message: "인수 금액이 추가 발생하는 구조입니다" }
  }.freeze

  def initialize(report:, property:)
    @report = report
    @property = property
    @simulation = report.report_data&.dig("dividend_simulation") || {}
    @burden = report.report_data&.dig("bidder_burden") || {}
  end

  private

  def expected_bid
    @simulation["expected_bid"]
  end

  def distribution
    @simulation["distribution"] || []
  end

  def burden_config
    BURDEN_CONFIG[@burden["verdict"]] || BURDEN_CONFIG["safe"]
  end

  def format_amount(amount)
    return "—" if amount.nil?
    amount.to_fs(:delimited)
  end
end
```

```erb
<%# app/components/dividend_simulator_component.html.erb %>
<div class="space-y-4">
  <div class="flex items-center gap-3">
    <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100">배당 시뮬레이션</h3>
    <span class="text-xs text-amber-600 dark:text-amber-400 bg-amber-50 dark:bg-amber-900/20 px-2 py-1 rounded">⚠️ 추정치 — 실제 배당과 다를 수 있습니다</span>
  </div>

  <%= form_with url: helpers.property_analyses_report_path(@property), method: :patch, class: "flex items-center gap-3 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-200 dark:border-slate-700 p-3",
      data: { controller: "dividend-simulator" } do |f| %>
    <label class="text-sm font-semibold text-slate-700 dark:text-slate-300 whitespace-nowrap">예상 낙찰가</label>
    <input type="text" name="expected_bid" value="<%= expected_bid %>"
           inputmode="numeric" placeholder="금액을 입력하세요"
           class="flex-1 rounded-md border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 px-3 py-2 text-sm text-slate-900 dark:text-slate-100"
           data-dividend-simulator-target="bidInput" />
    <span class="text-sm text-slate-500 dark:text-slate-400">원</span>
    <%= f.submit "계산", class: "rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 cursor-pointer" %>
  <% end %>

  <% if distribution.any? %>
    <div class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="bg-slate-100 dark:bg-slate-800">
            <th class="px-3 py-2 text-left font-medium text-slate-600 dark:text-slate-400">순위</th>
            <th class="px-3 py-2 text-left font-medium text-slate-600 dark:text-slate-400">채권자</th>
            <th class="px-3 py-2 text-left font-medium text-slate-600 dark:text-slate-400">유형</th>
            <th class="px-3 py-2 text-right font-medium text-slate-600 dark:text-slate-400">채권액</th>
            <th class="px-3 py-2 text-right font-medium text-slate-600 dark:text-slate-400">배당액</th>
            <th class="px-3 py-2 text-right font-medium text-slate-600 dark:text-slate-400">미배당</th>
          </tr>
        </thead>
        <tbody>
          <% distribution.each do |row| %>
            <tr class="border-b border-slate-100 dark:border-slate-800">
              <td class="px-3 py-2 text-slate-700 dark:text-slate-300"><%= row["priority"] %></td>
              <td class="px-3 py-2 font-medium text-slate-900 dark:text-slate-100"><%= row["holder"] %></td>
              <td class="px-3 py-2 text-slate-600 dark:text-slate-400"><%= row["type"] %></td>
              <td class="px-3 py-2 text-right text-slate-700 dark:text-slate-300"><%= format_amount(row["claim"]) %></td>
              <td class="px-3 py-2 text-right font-semibold text-green-700 dark:text-green-400"><%= format_amount(row["dividend"]) %></td>
              <td class="px-3 py-2 text-right <%= row["shortfall"].to_i > 0 ? 'text-red-600 dark:text-red-400' : 'text-slate-500 dark:text-slate-400' %>"><%= format_amount(row["shortfall"]) %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  <% end %>

  <%# Bidder Burden Summary %>
  <div class="rounded-lg border p-4 <%= burden_config[:bg] %>">
    <div class="text-sm font-semibold text-slate-900 dark:text-slate-100 mb-2">💰 낙찰자 부담 분석</div>
    <div class="grid grid-cols-3 gap-4 text-sm mb-3">
      <div>
        <span class="text-slate-500 dark:text-slate-400">인수 금액</span>
        <p class="font-semibold text-slate-900 dark:text-slate-100"><%= format_amount(@burden["assumed_amount"]) %>원</p>
      </div>
      <div>
        <span class="text-slate-500 dark:text-slate-400">미확인 위험</span>
        <p class="font-semibold text-slate-900 dark:text-slate-100"><%= format_amount(@burden["unconfirmed_risk"]) %>원</p>
      </div>
      <div>
        <span class="text-slate-500 dark:text-slate-400">실질 부담 총액</span>
        <p class="font-bold text-slate-900 dark:text-slate-100"><%= format_amount(@burden["total_burden"]) %>원</p>
      </div>
    </div>
    <div class="text-sm font-medium <%= burden_config[:color] %>">
      <% if @burden["verdict"] == "safe" %>✅<% elsif @burden["verdict"] == "caution" %>⚠️<% else %>🔴<% end %>
      <%= burden_config[:message] %>
    </div>
  </div>

  <div class="text-xs text-slate-500 dark:text-slate-400">
    정확한 배당 결과는 법원 배당표를 확인하세요.
  </div>
</div>
```

- [ ] **Step 7: Implement SourceDocViewerComponent**

```ruby
# app/components/source_doc_viewer_component.rb
class SourceDocViewerComponent < ViewComponent::Base
  def initialize(property:)
    @property = property
    @court_auction = property.raw_data&.dig("court_auction") || {}
    @registry_transcript = property.raw_data&.dig("registry_transcript") || {}
  end
end
```

```erb
<%# app/components/source_doc_viewer_component.html.erb %>
<div class="space-y-4" data-controller="source-doc-tracker">
  <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100">원문 뷰어</h3>

  <div class="flex border-b border-slate-200 dark:border-slate-700">
    <button class="px-4 py-2 text-sm font-medium border-b-2 border-blue-600 text-blue-600 dark:border-blue-400 dark:text-blue-400"
            data-source-doc-tracker-target="tab" data-action="click->source-doc-tracker#switchTab"
            data-doc-type="court_auction">매각물건명세서</button>
    <button class="px-4 py-2 text-sm font-medium border-b-2 border-transparent text-slate-500 dark:text-slate-400"
            data-source-doc-tracker-target="tab" data-action="click->source-doc-tracker#switchTab"
            data-doc-type="registry">등기부등본</button>
  </div>

  <div class="rounded-lg bg-amber-50 dark:bg-amber-900/20 border border-amber-300 dark:border-amber-600 px-3 py-2">
    <div class="text-xs font-semibold text-amber-800 dark:text-amber-200">⚠️ Mock 데이터 — 실제 연동 시 원본 문서로 교체됩니다</div>
  </div>

  <div data-source-doc-tracker-target="panel" data-doc-type="court_auction"
       class="rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4 text-sm font-mono leading-relaxed text-slate-700 dark:text-slate-300">
    <div class="font-semibold text-slate-900 dark:text-slate-100 mb-2">매각물건명세서 주요 내용</div>
    <% if @court_auction.any? %>
      <p>• 비고란: <%= @court_auction["remarks"] || "해당사항 없음" %></p>
      <p>• 소멸되지 아니하는 것: <%= @court_auction["non_extinguished_rights"]&.any? ? @court_auction["non_extinguished_rights"].join(", ") : "해당 없음" %></p>
      <p>• 유치권 신고: <%= @court_auction["lien_reported"] ? "있음" : "없음" %></p>
      <p>• 임차인: <%= @court_auction["tenants"]&.any? ? "#{@court_auction["tenants"].size}명" : "없음" %></p>
    <% else %>
      <p class="text-slate-500 dark:text-slate-400">매각물건명세서 데이터가 없습니다.</p>
    <% end %>
  </div>

  <div data-source-doc-tracker-target="panel" data-doc-type="registry" class="hidden rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4 text-sm font-mono leading-relaxed text-slate-700 dark:text-slate-300">
    <div class="font-semibold text-slate-900 dark:text-slate-100 mb-2">등기부등본 주요 내용</div>
    <% if @registry_transcript.any? %>
      <p>• 권리 설정: <%= (@registry_transcript["rights"] || []).size %>건</p>
      <p>• 임차인: <%= (@registry_transcript["tenants"] || []).size %>명</p>
      <p>• HUG 확약서: <%= @registry_transcript["hug_waiver"] ? "제출됨 (대항력 포기)" : "없음" %></p>
      <p>• 압류: <%= (@registry_transcript["seizures"] || []).size %>건</p>
    <% else %>
      <p class="text-slate-500 dark:text-slate-400">등기부등본 데이터가 없습니다.</p>
    <% end %>
  </div>

  <div class="rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-700 px-3 py-2 text-xs text-red-800 dark:text-red-200">
    ⚠️ 반드시 매각물건명세서 비고란을 직접 확인하세요. 본 서비스는 분석 결과의 정확성을 보증하지 않습니다.
  </div>
</div>
```

- [ ] **Step 8: Implement LegalDisclaimerComponent**

```ruby
# app/components/legal_disclaimer_component.rb
class LegalDisclaimerComponent < ViewComponent::Base
end
```

```erb
<%# app/components/legal_disclaimer_component.html.erb %>
<div class="mt-8 rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 px-4 py-3 text-xs text-slate-500 dark:text-slate-400 leading-relaxed">
  <div class="font-semibold text-slate-600 dark:text-slate-300 mb-1">⚖️ 법적 고지</div>
  <p>본 서비스의 권리 분석은 등기부등본, 매각물건명세서 등 공적 데이터를 기반으로 대한민국 민사집행법의 배당 원칙에 따라 체계적으로 수행됩니다. 다만 모든 분석 결과는 참고용이며, 법적 자문에 해당하지 않습니다. 실제 경매에서는 법원의 판단, 미공시 권리관계 등 본 서비스가 파악할 수 없는 변수가 존재할 수 있으므로, 분석 결과의 정확성 또는 완전성을 보증하지 않으며, 이를 근거로 한 투자 판단에 대해 법적 책임을 지지 않습니다. 중요한 결정 전에 반드시 법률 전문가의 자문을 받으시기 바랍니다.</p>
</div>
```

- [ ] **Step 9: Run all component tests**

Run: `bin/rails test test/components/report_summary_component_test.rb test/components/registry_timeline_component_test.rb test/components/dividend_simulator_component_test.rb test/components/source_doc_viewer_component_test.rb`
Expected: All tests PASS.

- [ ] **Step 10: Commit**

```bash
git add app/components/report_summary_component* app/components/registry_timeline_component* app/components/dividend_simulator_component* app/components/source_doc_viewer_component* app/components/legal_disclaimer_component* test/components/report_summary_component_test.rb test/components/registry_timeline_component_test.rb test/components/dividend_simulator_component_test.rb test/components/source_doc_viewer_component_test.rb
git commit -m "feat(f03): add report section ViewComponents (summary, timeline, dividend, source doc, disclaimer)"
```

---

## Task 16: Views — Report Show + Property Show Restructure

**Files:**
- Create: `app/views/analyses/reports/show.html.erb`
- Modify: `app/views/properties/show.html.erb`

- [ ] **Step 1: Create report view**

```erb
<%# app/views/analyses/reports/show.html.erb %>
<%= turbo_frame_tag "tab_content" do %>
  <div class="space-y-8">
    <%= render ReportSummaryComponent.new(report: @report) %>
    <%= render RegistryTimelineComponent.new(report: @report) %>
    <%= render DividendSimulatorComponent.new(report: @report, property: @property) %>
    <%= render SourceDocViewerComponent.new(property: @property) %>
    <%= render LegalDisclaimerComponent.new %>
  </div>
<% end %>
```

- [ ] **Step 2: Restructure properties/show with tabs**

Replace `app/views/properties/show.html.erb` with tab-based layout:

```erb
<%# app/views/properties/show.html.erb %>
<div class="space-y-4">
  <div class="flex items-center gap-2">
    <%= link_to "← 목록", properties_path, class: "text-sm text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300" %>
  </div>

  <%= render CardComponent.new(title: @property.case_number) do |card| %>
    <div class="space-y-3">
      <div class="flex items-center gap-2">
        <%= render SafetyBadgeComponent.new(rating: @user_property&.safety_rating) %>
        <% if @property.court_name.present? %>
          <span class="text-sm text-slate-500 dark:text-slate-400"><%= @property.court_name %></span>
        <% end %>
      </div>
      <p class="text-sm text-slate-700 dark:text-slate-300"><%= @property.address %></p>
      <div class="grid grid-cols-2 gap-4 text-sm">
        <div>
          <span class="text-slate-500 dark:text-slate-400">감정가</span>
          <p class="font-semibold text-slate-900 dark:text-slate-100"><%= format_price_in_eok(@property.appraisal_price) %></p>
        </div>
        <div>
          <span class="text-slate-500 dark:text-slate-400">최저매각가</span>
          <p class="font-semibold text-slate-900 dark:text-slate-100"><%= format_price_in_eok(@property.min_bid_price) %></p>
        </div>
      </div>
    </div>
  <% end %>

  <%= render PropertyTabsComponent.new(property: @property, user: current_user, active_tab: :info) %>

  <%= turbo_frame_tag "tab_content" do %>
    <div class="text-center space-y-3">
      <% if @user_property&.safety_rating.present? %>
        <p class="text-sm text-slate-600 dark:text-slate-400">분석이 완료되었습니다. 탭을 선택하여 결과를 확인하세요.</p>
        <div class="flex justify-center gap-3">
          <%= button_to "다시 분석하기", property_analyses_start_path(@property), method: :post,
              class: "inline-flex items-center rounded-md bg-slate-100 dark:bg-slate-700 px-4 py-2 text-sm font-medium text-slate-700 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-600" %>
        </div>
      <% else %>
        <%= button_to "분석 시작", property_analyses_start_path(@property), method: :post,
            class: "inline-flex items-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700" %>
      <% end %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 3: Run all tests**

Run: `bin/rails test`
Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
git add app/views/analyses/reports/show.html.erb app/views/properties/show.html.erb
git commit -m "feat(f03): add report view and restructure property show with tab navigation"
```

---

## Task 17: Stimulus Controllers

**Files:**
- Create: `app/javascript/controllers/property_tabs_controller.js`
- Create: `app/javascript/controllers/dividend_simulator_controller.js`
- Create: `app/javascript/controllers/source_doc_tracker_controller.js`

- [ ] **Step 1: Create property_tabs_controller**

```javascript
// app/javascript/controllers/property_tabs_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Tab switching is handled by Turbo Frame links — this controller
  // tracks state only (e.g., for the source doc confirmation popup)
  static values = { sourceDocViewed: Boolean }

  connect() {
    this.sourceDocViewedValue = false
  }

  markSourceDocViewed() {
    this.sourceDocViewedValue = true
  }
}
```

- [ ] **Step 2: Create dividend_simulator_controller**

```javascript
// app/javascript/controllers/dividend_simulator_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bidInput"]

  formatInput() {
    const input = this.bidInputTarget
    const raw = input.value.replace(/[^0-9]/g, "")
    input.value = raw ? Number(raw).toLocaleString() : ""
  }
}
```

- [ ] **Step 3: Create source_doc_tracker_controller**

```javascript
// app/javascript/controllers/source_doc_tracker_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { viewed: { type: Boolean, default: false } }

  switchTab(event) {
    const docType = event.currentTarget.dataset.docType
    this.viewedValue = true

    // Update tab styles
    this.tabTargets.forEach(tab => {
      if (tab.dataset.docType === docType) {
        tab.classList.add("border-blue-600", "text-blue-600", "dark:border-blue-400", "dark:text-blue-400")
        tab.classList.remove("border-transparent", "text-slate-500", "dark:text-slate-400")
      } else {
        tab.classList.remove("border-blue-600", "text-blue-600", "dark:border-blue-400", "dark:text-blue-400")
        tab.classList.add("border-transparent", "text-slate-500", "dark:text-slate-400")
      }
    })

    // Show/hide panels
    this.panelTargets.forEach(panel => {
      if (panel.dataset.docType === docType) {
        panel.classList.remove("hidden")
      } else {
        panel.classList.add("hidden")
      }
    })
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add app/javascript/controllers/property_tabs_controller.js app/javascript/controllers/dividend_simulator_controller.js app/javascript/controllers/source_doc_tracker_controller.js
git commit -m "feat(f03): add Stimulus controllers for tabs, dividend simulation, source doc tracking"
```

---

## Task 18: Integration Test

**Files:**
- Create: `test/integration/rights_analysis_flow_test.rb`

- [ ] **Step 1: Write integration test**

```ruby
# test/integration/rights_analysis_flow_test.rb
require "test_helper"

class RightsAnalysisFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:guest)
    # Auto-login as guest
    get properties_url
    @property = PropertyDataSyncService.call(case_number: "2026타경10002")
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "full analysis flow creates report" do
    # Start analysis
    post property_analyses_start_url(@property)
    assert_redirected_to edit_property_analyses_checklist_url(@property)

    # Verify report was created
    report = RightsAnalysisReport.find_by(user: @user, property: @property)
    assert_not_nil report
    assert_equal "근저당", report.base_right_type
  end

  test "report page shows analysis results" do
    # Run analysis first
    PropertyAnalysisService.call(property: @property, user: @user)
    RightsAnalysisService.call(property: @property, user: @user)

    get property_analyses_report_url(@property)
    assert_response :success
  end

  test "dividend simulation updates report" do
    RightsAnalysisService.call(property: @property, user: @user)

    patch property_analyses_report_url(@property), params: { expected_bid: 100_000_000 }
    assert_redirected_to property_analyses_report_url(@property)

    report = RightsAnalysisReport.find_by(user: @user, property: @property)
    assert_equal 100_000_000, report.report_data.dig("dividend_simulation", "expected_bid")
    assert report.report_data.dig("dividend_simulation", "distribution").any?
  end

  test "HUG opportunity detection works end-to-end" do
    hug_property = PropertyDataSyncService.call(case_number: "2026타경10003")
    UserProperty.find_or_create_by!(user: @user, property: hug_property)

    post property_analyses_start_url(hug_property)

    report = RightsAnalysisReport.find_by(user: @user, property: hug_property)
    assert_equal "hug_waiver", report.opportunity_type
  end
end
```

- [ ] **Step 2: Run integration test**

Run: `bin/rails test test/integration/rights_analysis_flow_test.rb`
Expected: All 4 tests PASS.

- [ ] **Step 3: Run full test suite**

Run: `bin/rails test`
Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
git add test/integration/rights_analysis_flow_test.rb
git commit -m "test(f03): add integration tests for rights analysis flow"
```

---

## Task 19: Cleanup + Final Verification

- [ ] **Step 1: Run rubocop**

Run: `bin/rubocop`
Fix any style violations in new files.

- [ ] **Step 2: Run brakeman security check**

Run: `bin/brakeman --quiet --no-pager`
Expected: No new warnings.

- [ ] **Step 3: Run full CI**

Run: `bin/ci`
Expected: All checks pass.

- [ ] **Step 4: Fix any issues and commit**

```bash
git add -u
git commit -m "fix(f03): address rubocop and brakeman findings"
```

- [ ] **Step 5: Verify seed data still works**

Run: `bin/rails db:reset && bin/rails db:seed`
Expected: Seeds load without error.

- [ ] **Step 6: Manual smoke test**

Run: `bin/dev`
Navigate to a property → click "분석 시작" → verify:
1. ①②③④ tabs appear
2. ② 체크리스트 tab shows checklist results
3. ③ 권리 분석 tab shows report with summary, timeline, dividend form, source doc viewer
4. Enter expected bid → click 계산 → dividend table appears with bidder burden summary
5. ④ 등급 산정 tab shows safety rating

- [ ] **Step 7: Final commit if any smoke test fixes**

```bash
git add -u
git commit -m "fix(f03): smoke test fixes"
```
