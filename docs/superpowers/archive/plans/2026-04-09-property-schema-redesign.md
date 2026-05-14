# Property Schema Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single `properties` table with `raw_data` JSON blob with 5 normalized tables storing 56 structured columns from court auction search + detail APIs.

**Architecture:** Create 4 new tables (`property_sale_details`, `auction_schedules`, `land_details`, `appraisal_points`) via migrations. Rewrite `properties` columns (remove `raw_data`, `court_name`; add 18 new columns). Update `ResponseParser`, `PropertyDataSyncService`, `InspectionRunner`, `RightsAnalysisService`, `SourceDocViewerComponent`, seeds, and all tests to use structured columns instead of JSON paths.

**Tech Stack:** Rails 8.1, SQLite, Minitest, Ferrum (browser automation)

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `db/migrate/TIMESTAMP_redesign_properties_schema.rb` | Single migration: alter properties + create 4 new tables |
| Modify | `app/models/property.rb` | Add associations to 4 new tables |
| Create | `app/models/property_sale_detail.rb` | 1:1 sale specification data |
| Create | `app/models/auction_schedule.rb` | 1:N auction date history |
| Create | `app/models/land_detail.rb` | 1:N land parcel data |
| Create | `app/models/appraisal_point.rb` | 1:N appraisal key points |
| Modify | `app/services/property_data_sync_service.rb` | Persist to all 5 tables |
| Modify | `app/adapters/court_auction/response_parser.rb` | Return flat hash with all 56 fields |
| Modify | `app/services/inspection_runner.rb` | Read structured columns, not raw_data |
| Modify | `app/services/rights_analysis_service.rb` | Read `raw_data["registry_transcript"]` unchanged (out of scope for court auction redesign) |
| Modify | `app/components/source_doc_viewer_component.rb` | Read from sale_detail association |
| Modify | `app/components/source_doc_viewer_component.html.erb` | Use structured fields |
| Modify | `app/controllers/properties_controller.rb` | Remove `court_name` from search query |
| Modify | `db/seeds.rb` | Seed all 5 tables from JSON |
| Modify | `db/seeds/real_properties.json` | Restructured with nested detail data |
| Modify | `test/fixtures/properties.yml` | Add new columns |
| Create | `test/fixtures/property_sale_details.yml` | Fixture data |
| Create | `test/fixtures/auction_schedules.yml` | Fixture data |
| Modify | `test/models/property_test.rb` | Test new associations + validations |
| Create | `test/models/property_sale_detail_test.rb` | Test model |
| Modify | `test/services/property_data_sync_service_test.rb` | Test structured persistence |
| Modify | `test/services/inspection_runner_test.rb` | Test new rule paths |
| Modify | `test/adapters/court_auction/response_parser_test.rb` | Test new parsing |

---

### Task 1: Database Migration

**Files:**
- Create: `db/migrate/TIMESTAMP_redesign_properties_schema.rb`

- [ ] **Step 1: Generate migration**

Run:
```bash
bin/rails generate migration RedesignPropertiesSchema
```

- [ ] **Step 2: Write migration**

Edit the generated migration file:

```ruby
class RedesignPropertiesSchema < ActiveRecord::Migration[8.1]
  def change
    # === Alter properties table ===
    remove_column :properties, :court_name, :string
    remove_column :properties, :raw_data, :json

    add_column :properties, :case_type, :string
    add_column :properties, :claim_amount, :bigint
    add_column :properties, :property_usage_code, :string
    add_column :properties, :sido, :string
    add_column :properties, :sigungu, :string
    add_column :properties, :dong, :string
    add_column :properties, :building_name, :string
    add_column :properties, :building_detail, :string
    add_column :properties, :building_structure, :string
    add_column :properties, :exclusive_area, :decimal
    add_column :properties, :land_category, :string
    add_column :properties, :failed_bid_count, :integer, default: 0
    add_column :properties, :view_count, :integer, default: 0
    add_column :properties, :interest_count, :integer, default: 0
    add_column :properties, :latitude, :decimal, precision: 10, scale: 7
    add_column :properties, :longitude, :decimal, precision: 10, scale: 7
    add_column :properties, :special_conditions_code, :string
    add_column :properties, :remarks, :text

    # Change price columns from integer to bigint
    change_column :properties, :appraisal_price, :bigint
    change_column :properties, :min_bid_price, :bigint

    add_index :properties, [:sido, :sigungu, :dong], name: "idx_properties_location"
    add_index :properties, :property_type

    # === Create property_sale_details (1:1) ===
    create_table :property_sale_details do |t|
      t.references :property, null: false, foreign_key: true, index: { unique: true }
      t.text :non_extinguished_rights
      t.text :superficies_details
      t.text :specification_remarks
      t.string :senior_mortgage_basis
      t.text :goods_remarks
      t.date :dividend_demand_deadline
      t.text :share_description
      t.bigint :price_round_1
      t.bigint :price_round_2
      t.bigint :price_round_3
      t.bigint :price_round_4
      t.timestamps
    end

    # === Create auction_schedules (1:N) ===
    create_table :auction_schedules do |t|
      t.references :property, null: false, foreign_key: true
      t.date :schedule_date
      t.string :schedule_time
      t.date :bid_start_date
      t.date :bid_end_date
      t.string :place
      t.string :schedule_type
      t.string :result_code
      t.bigint :min_price
      t.bigint :sale_amount
      t.timestamps
    end

    add_index :auction_schedules, [:property_id, :schedule_date], name: "idx_auction_schedules_date"

    # === Create land_details (1:N) ===
    create_table :land_details do |t|
      t.references :property, null: false, foreign_key: true
      t.string :land_type
      t.string :land_area
      t.string :land_category
      t.string :share_ratio
      t.string :address
      t.string :lot_number
      t.timestamps
    end

    # === Create appraisal_points (1:N) ===
    create_table :appraisal_points do |t|
      t.references :property, null: false, foreign_key: true
      t.string :item_code
      t.text :content
      t.timestamps
    end

    add_index :appraisal_points, [:property_id, :item_code], name: "idx_appraisal_points_item"
  end
end
```

- [ ] **Step 3: Run migration**

Run:
```bash
bin/rails db:migrate
```
Expected: Migration succeeds, `db/schema.rb` updated with new tables.

- [ ] **Step 4: Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "db: redesign properties schema with 5 normalized tables"
```

---

### Task 2: Models

**Files:**
- Modify: `app/models/property.rb`
- Create: `app/models/property_sale_detail.rb`
- Create: `app/models/auction_schedule.rb`
- Create: `app/models/land_detail.rb`
- Create: `app/models/appraisal_point.rb`
- Modify: `test/models/property_test.rb`
- Create: `test/models/property_sale_detail_test.rb`
- Modify: `test/fixtures/properties.yml`
- Create: `test/fixtures/property_sale_details.yml`
- Create: `test/fixtures/auction_schedules.yml`
- Create: `test/fixtures/land_details.yml`
- Create: `test/fixtures/appraisal_points.yml`

- [ ] **Step 1: Write fixtures**

`test/fixtures/properties.yml`:
```yaml
safe_apartment:
  case_number: "2026타경10001"
  case_type: "부동산임의경매"
  property_type: "아파트"
  address: "서울특별시 강남구 역삼동 100-1"
  sido: "서울특별시"
  sigungu: "강남구"
  dong: "역삼동"
  building_name: "테스트아파트"
  building_detail: "101동 5층501호"
  building_structure: "철근콩크리트조 84.50㎡"
  exclusive_area: 84.5
  land_category: "전유"
  appraisal_price: 800000000
  min_bid_price: 560000000
  failed_bid_count: 0
  view_count: 5
  interest_count: 2
  latitude: 37.5012
  longitude: 127.0396
  status: "진행중"
  remarks: ""

risky_villa:
  case_number: "2026타경10002"
  case_type: "부동산임의경매"
  property_type: "빌라"
  address: "경기도 수원시 영통구 200-2"
  sido: "경기도"
  sigungu: "수원시"
  dong: "영통구"
  building_name: "테스트빌라"
  building_detail: "3층301호"
  building_structure: "철근콩크리트조 60.00㎡"
  exclusive_area: 60.0
  land_category: "전유"
  appraisal_price: 300000000
  min_bid_price: 210000000
  failed_bid_count: 2
  view_count: 15
  interest_count: 5
  status: "진행중"
  remarks: "유치권 신고 있음"

unanalyzed_officetel:
  case_number: "2026타경10003"
  case_type: "부동산임의경매"
  property_type: "오피스텔"
  address: "인천광역시 연수구 300-3"
  sido: "인천광역시"
  sigungu: "연수구"
  dong: ""
  building_name: "테스트오피스텔"
  building_detail: "10층1001호"
  building_structure: "철근콩크리트조 45.00㎡"
  exclusive_area: 45.0
  land_category: "전유"
  appraisal_price: 250000000
  min_bid_price: 175000000
  failed_bid_count: 0
  view_count: 0
  interest_count: 0
  status: "진행중"
  remarks: ""
```

`test/fixtures/property_sale_details.yml`:
```yaml
safe_apartment_detail:
  property: safe_apartment
  non_extinguished_rights: ""
  specification_remarks: ""
  senior_mortgage_basis: "2020.5.27. 근저당권"
  goods_remarks: ""
  dividend_demand_deadline: "2026-07-01"
  share_description: ""

risky_villa_detail:
  property: risky_villa
  non_extinguished_rights: "을구 1번 주택임차권등기 — 배당에서 전액 변제받지 않으면 매수인이 인수"
  specification_remarks: "유치권 신고 있음"
  senior_mortgage_basis: "2021.3.31. 근저당권"
  goods_remarks: "유치권 신고"
  dividend_demand_deadline: "2026-06-01"
  share_description: ""
```

`test/fixtures/auction_schedules.yml`:
```yaml
safe_apartment_schedule_1:
  property: safe_apartment
  schedule_date: "2026-04-16"
  schedule_time: "1000"
  place: "경매법정"
  schedule_type: "01"
  min_price: 560000000
  sale_amount: 0
```

`test/fixtures/land_details.yml`:
```yaml
safe_apartment_land:
  property: safe_apartment
  land_type: "전유"
  land_area: "5000.0㎡"
  land_category: "대"
  share_ratio: "84.5/5000.0"
  address: "서울특별시강남구역삼동100"
  lot_number: "100"
```

`test/fixtures/appraisal_points.yml`:
```yaml
safe_apartment_location:
  property: safe_apartment
  item_code: "00083001"
  content: "역삼역 인근에 위치하며 주위는 아파트단지 및 상가 등이 소재함."

safe_apartment_lease:
  property: safe_apartment
  item_code: "00083026"
  content: "임대관계 미상임."
```

- [ ] **Step 2: Write model files**

`app/models/property.rb`:
```ruby
class Property < ApplicationRecord
  has_one :sale_detail, class_name: "PropertySaleDetail", dependent: :destroy
  has_many :auction_schedules, dependent: :destroy
  has_many :land_details, dependent: :destroy
  has_many :appraisal_points, dependent: :destroy

  has_many :user_properties, dependent: :destroy
  has_many :users, through: :user_properties
  has_many :inspection_results, dependent: :destroy
  has_many :inspection_items, through: :inspection_results
  has_many :rights_analysis_reports, dependent: :destroy

  validates :case_number, presence: true, uniqueness: true
end
```

`app/models/property_sale_detail.rb`:
```ruby
class PropertySaleDetail < ApplicationRecord
  belongs_to :property
end
```

`app/models/auction_schedule.rb`:
```ruby
class AuctionSchedule < ApplicationRecord
  belongs_to :property
end
```

`app/models/land_detail.rb`:
```ruby
class LandDetail < ApplicationRecord
  belongs_to :property
end
```

`app/models/appraisal_point.rb`:
```ruby
class AppraisalPoint < ApplicationRecord
  belongs_to :property
end
```

- [ ] **Step 3: Write model tests**

`test/models/property_test.rb`:
```ruby
require "test_helper"

class PropertyTest < ActiveSupport::TestCase
  test "valid with all required fields" do
    property = Property.new(
      case_number: "2026타경12345",
      address: "서울특별시 강남구 역삼동 123-45",
      appraisal_price: 500000000,
      min_bid_price: 350000000
    )
    assert property.valid?
  end

  test "case_number is required" do
    property = Property.new(case_number: nil)
    assert_not property.valid?
    assert_includes property.errors[:case_number], "can't be blank"
  end

  test "case_number must be unique" do
    Property.create!(case_number: "2026타경12345", address: "서울시", appraisal_price: 500000000, min_bid_price: 350000000)
    duplicate = Property.new(case_number: "2026타경12345")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:case_number], "has already been taken"
  end

  test "has_one sale_detail" do
    property = properties(:safe_apartment)
    assert_respond_to property, :sale_detail
    assert_instance_of PropertySaleDetail, property.sale_detail
  end

  test "has_many auction_schedules" do
    property = properties(:safe_apartment)
    assert_respond_to property, :auction_schedules
  end

  test "has_many land_details" do
    property = properties(:safe_apartment)
    assert_respond_to property, :land_details
  end

  test "has_many appraisal_points" do
    property = properties(:safe_apartment)
    assert_respond_to property, :appraisal_points
  end

  test "has_many inspection_results" do
    property = properties(:safe_apartment)
    assert_respond_to property, :inspection_results
  end

  test "has_many user_properties" do
    property = properties(:safe_apartment)
    assert_respond_to property, :user_properties
  end

  test "destroying property cascades to sale_detail" do
    property = properties(:safe_apartment)
    detail_id = property.sale_detail.id
    property.destroy
    assert_nil PropertySaleDetail.find_by(id: detail_id)
  end
end
```

`test/models/property_sale_detail_test.rb`:
```ruby
require "test_helper"

class PropertySaleDetailTest < ActiveSupport::TestCase
  test "belongs to property" do
    detail = property_sale_details(:safe_apartment_detail)
    assert_equal properties(:safe_apartment), detail.property
  end

  test "can store non_extinguished_rights text" do
    detail = property_sale_details(:risky_villa_detail)
    assert detail.non_extinguished_rights.present?
    assert detail.non_extinguished_rights.include?("임차권등기")
  end
end
```

- [ ] **Step 4: Run tests**

Run: `bin/rails test test/models/property_test.rb test/models/property_sale_detail_test.rb`
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add app/models/ test/models/ test/fixtures/
git commit -m "feat: add Property associations and 4 new models with fixtures"
```

---

### Task 3: ResponseParser Rewrite

**Files:**
- Modify: `app/adapters/court_auction/response_parser.rb`
- Modify: `test/adapters/court_auction/response_parser_test.rb`

- [ ] **Step 1: Write test for new parsing**

`test/adapters/court_auction/response_parser_test.rb`:
```ruby
require "test_helper"

class CourtAuction::ResponseParserTest < ActiveSupport::TestCase
  setup do
    @parser = CourtAuction::ResponseParser.new
    @search_response = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_search_intercepted.json"))
    )
  end

  test "parse extracts basic fields from search response" do
    result = @parser.parse(api_response: @search_response)
    assert_equal "2026타경10001", result[:case_number]
    assert result[:appraisal_price].is_a?(Integer)
    assert result[:min_bid_price].is_a?(Integer)
  end

  test "parse returns nil for empty result set" do
    empty = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_empty_search.json"))
    )
    assert_nil @parser.parse(api_response: empty)
  end

  test "parse extracts address components" do
    result = @parser.parse(api_response: @search_response)
    assert result[:sido].present?
    assert result[:sigungu].present?
  end

  test "parse extracts building info" do
    result = @parser.parse(api_response: @search_response)
    assert result.key?(:building_name)
    assert result.key?(:building_detail)
    assert result.key?(:building_structure)
  end

  test "parse_with_detail merges detail data" do
    detail_response = {
      "data" => {
        "dma_result" => {
          "csBaseInfo" => { "csNm" => "부동산임의경매", "clmAmt" => 500000000 },
          "dspslGdsDxdyInfo" => {
            "ndstrcRghCtt" => "을구 1번 임차권등기",
            "gdsSpcfcRmk" => "특별매각조건",
            "dspslGdsRmk" => nil,
            "tprtyRnkHypthcStngDts" => "2020.5.27. 근저당권",
            "fstPbancLwsDspslPrc" => 800000000,
            "scndPbancLwsDspslPrc" => 640000000,
            "thrdPbancLwsDspslPrc" => nil,
            "fothPbancLwsDspslPrc" => nil
          },
          "dstrtDemnInfo" => [{ "dstrtDemnLstprdYmd" => "20260701" }],
          "gdsDspslObjctLst" => [{
            "rletDvsDts" => "전유",
            "dspslStkCtt" => nil,
            "bldDtlDts" => "101동 5층501호",
            "bldNm" => "테스트아파트",
            "pjbBuldList" => "철근콩크리트조 84.50㎡",
            "dspslStkNmrtVal" => 0,
            "dspslStkDnmnVal" => 0
          }],
          "gdsDspslDxdyLst" => [{
            "dxdyYmd" => "20260416",
            "dxdyHm" => "1000",
            "bidBgngYmd" => nil,
            "bidEndYmd" => nil,
            "dxdyPlcNm" => "경매법정",
            "auctnDxdyKndCd" => "01",
            "auctnDxdyRsltCd" => nil,
            "tsLwsDspslPrc" => 560000000,
            "dspslAmt" => 0
          }],
          "rgltLandLstAll" => [[{
            "rletDvsDts" => "전유",
            "landArDts" => "5000.0㎡",
            "landLdcgDts" => "대",
            "rgltRateNmrtVal" => "84.5",
            "rgltRateDnmnVal" => "5000.0",
            "rletIndctDts" => "서울특별시강남구역삼동100",
            "rgltLandLtnoAddr" => "100"
          }]],
          "aeeWevlMnpntLst" => [{
            "aeeWevlMnpntItmCd" => "00083026",
            "aeeWevlMnpntCtt" => "임대관계 미상임."
          }]
        }
      }
    }

    result = @parser.parse_with_detail(
      search_response: @search_response,
      detail_response: detail_response
    )

    assert_equal "부동산임의경매", result[:case_type]
    assert_equal 500000000, result[:claim_amount]
    assert_equal "을구 1번 임차권등기", result[:non_extinguished_rights]
    assert_equal "2020.5.27. 근저당권", result[:senior_mortgage_basis]
    assert_equal 800000000, result[:price_round_1]
    assert_equal 640000000, result[:price_round_2]
    assert_nil result[:price_round_3]
    assert_equal 1, result[:auction_schedules].size
    assert_equal 1, result[:land_details].size
    assert_equal 1, result[:appraisal_points].size
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/adapters/court_auction/response_parser_test.rb`
Expected: New tests fail (old `parse_with_detail` returns different structure).

- [ ] **Step 3: Rewrite ResponseParser**

`app/adapters/court_auction/response_parser.rb`:
```ruby
module CourtAuction
  class ResponseParser
    REQUIRED_FIELDS = %i[case_number address appraisal_price min_bid_price].freeze

    def parse(api_response:)
      items = extract_items(api_response)
      return nil if items.nil? || items.empty?

      item = items.first
      result = build_search_result(item)
      validate!(result)
      result
    end

    def parse_with_detail(search_response:, detail_response:)
      result = parse(api_response: search_response)
      return nil if result.nil?

      detail = detail_response&.dig("data", "dma_result")
      return result if detail.nil?

      merge_detail(result, detail)
    end

    private

    def extract_items(response)
      items = response.dig("data", "dlt_srchResult")
      raise DataProvider::ParseError, "Unexpected response structure" if items.nil?
      items
    rescue NoMethodError
      raise DataProvider::ParseError, "Unexpected response structure"
    end

    def build_search_result(item)
      {
        case_number: item["srnSaNo"],
        property_type: item["dspslUsgNm"],
        property_usage_code: item["maemulUtilCd"],
        status: item["mulJinYn"] == "Y" ? "진행중" : "종결",
        address: item["printSt"],
        sido: item["hjguSido"],
        sigungu: item["hjguSigu"],
        dong: item["hjguDong"],
        building_name: item["buldNm"],
        building_detail: item["buldList"],
        building_structure: item["pjbBuldList"],
        exclusive_area: item["minArea"].to_f,
        appraisal_price: parse_price(item["gamevalAmt"]),
        min_bid_price: parse_price(item["minmaePrice"]),
        failed_bid_count: item["yuchalCnt"].to_i,
        view_count: item["inqCnt"].to_i,
        interest_count: item["gwansMulRegCnt"].to_i,
        latitude: item["wgs84Ycordi"].to_f,
        longitude: item["wgs84Xcordi"].to_f,
        special_conditions_code: item["spJogCd"],
        remarks: item["mulBigo"] || ""
      }
    end

    def merge_detail(result, detail)
      base = detail["csBaseInfo"] || {}
      dxdy = detail["dspslGdsDxdyInfo"] || {}
      objct = (detail["gdsDspslObjctLst"] || []).first || {}
      demand = (detail["dstrtDemnInfo"] || []).first

      # Properties-level fields from detail
      result[:case_type] = base["csNm"]
      result[:claim_amount] = base["clmAmt"]
      result[:land_category] = objct["rletDvsDts"]
      result[:building_detail] = objct["bldDtlDts"].presence || result[:building_detail]
      result[:building_name] = objct["bldNm"].presence || result[:building_name]
      result[:building_structure] = objct["pjbBuldList"].presence || result[:building_structure]

      # Sale detail fields
      result[:non_extinguished_rights] = normalize_rights(dxdy["ndstrcRghCtt"])
      result[:superficies_details] = dxdy["sprfcExstcDts"]
      result[:specification_remarks] = dxdy["gdsSpcfcRmk"]
      result[:senior_mortgage_basis] = dxdy["tprtyRnkHypthcStngDts"]
      result[:goods_remarks] = dxdy["dspslGdsRmk"]
      result[:dividend_demand_deadline] = parse_date(demand&.dig("dstrtDemnLstprdYmd"))
      result[:share_description] = objct["dspslStkCtt"]
      result[:price_round_1] = dxdy["fstPbancLwsDspslPrc"]
      result[:price_round_2] = dxdy["scndPbancLwsDspslPrc"]
      result[:price_round_3] = dxdy["thrdPbancLwsDspslPrc"]
      result[:price_round_4] = dxdy["fothPbancLwsDspslPrc"]

      # Auction schedules (array)
      result[:auction_schedules] = (detail["gdsDspslDxdyLst"] || []).map do |s|
        {
          schedule_date: parse_date(s["dxdyYmd"]),
          schedule_time: s["dxdyHm"],
          bid_start_date: parse_date(s["bidBgngYmd"]),
          bid_end_date: parse_date(s["bidEndYmd"]),
          place: s["dxdyPlcNm"],
          schedule_type: s["auctnDxdyKndCd"],
          result_code: s["auctnDxdyRsltCd"],
          min_price: s["tsLwsDspslPrc"],
          sale_amount: s["dspslAmt"]
        }
      end

      # Land details (nested array)
      result[:land_details] = (detail["rgltLandLstAll"] || []).flat_map do |group|
        (group || []).map do |l|
          {
            land_type: l["rletDvsDts"],
            land_area: l["landArDts"],
            land_category: l["landLdcgDts"],
            share_ratio: "#{l['rgltRateNmrtVal']}/#{l['rgltRateDnmnVal']}",
            address: l["rletIndctDts"],
            lot_number: l["rgltLandLtnoAddr"]
          }
        end
      end

      # Appraisal points
      result[:appraisal_points] = (detail["aeeWevlMnpntLst"] || []).map do |p|
        {
          item_code: p["aeeWevlMnpntItmCd"],
          content: p["aeeWevlMnpntCtt"]
        }
      end

      result
    end

    def normalize_rights(text)
      return nil if text.blank? || text.strip == "해당사항없음" || text.strip == "해당 없음"
      text.strip
    end

    def parse_price(value)
      return nil if value.blank?
      value.to_i
    end

    def parse_date(value)
      return nil if value.blank?
      Date.parse(value) rescue nil
    end

    def validate!(result)
      missing = REQUIRED_FIELDS.select { |f| result[f].blank? }
      if missing.any?
        raise DataProvider::ParseError,
          "Missing required fields: #{missing.join(', ')}"
      end
    end
  end
end
```

- [ ] **Step 4: Run tests**

Run: `bin/rails test test/adapters/court_auction/response_parser_test.rb`
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add app/adapters/court_auction/response_parser.rb test/adapters/court_auction/response_parser_test.rb
git commit -m "feat: rewrite ResponseParser for normalized schema"
```

---

### Task 4: PropertyDataSyncService Rewrite

**Files:**
- Modify: `app/services/property_data_sync_service.rb`
- Modify: `test/services/property_data_sync_service_test.rb`

- [ ] **Step 1: Write test**

`test/services/property_data_sync_service_test.rb`:
```ruby
require "test_helper"

class PropertyDataSyncServiceTest < ActiveSupport::TestCase
  test "creates property with structured columns" do
    Property.find_by(case_number: "2026타경10001")&.destroy
    assert_difference "Property.count", 1 do
      result = PropertyDataSyncService.call(case_number: "2026타경10001")
      property = result.property
      assert_equal "2026타경10001", property.case_number
      assert_equal "아파트", property.property_type
      assert property.sido.present?
      assert property.appraisal_price > 0
    end
  end

  test "creates sale_detail for property" do
    Property.find_by(case_number: "2026타경10001")&.destroy
    result = PropertyDataSyncService.call(case_number: "2026타경10001")
    property = result.property
    assert property.sale_detail.present?
    assert property.sale_detail.senior_mortgage_basis.present?
  end

  test "upserts existing property without duplicating" do
    PropertyDataSyncService.call(case_number: "2026타경10001")
    assert_no_difference "Property.count" do
      result = PropertyDataSyncService.call(case_number: "2026타경10001")
      assert_equal "2026타경10001", result.property.case_number
    end
  end

  test "stores building_ledger and registry_transcript in raw_data" do
    result = PropertyDataSyncService.call(case_number: "2026타경10002")
    property = result.property
    # building_ledger and registry_transcript still stored in raw_data
    # since they come from separate adapters
    assert property.raw_data.key?("building_ledger") if result.building_data
    assert property.raw_data.key?("registry_transcript") if result.registry_data
  end

  test "returns Result with court_data, building_data, registry_data, errors" do
    result = PropertyDataSyncService.call(case_number: "2026타경10001")
    assert_respond_to result, :court_data
    assert_respond_to result, :building_data
    assert_respond_to result, :registry_data
    assert_respond_to result, :errors
    assert_respond_to result, :property
  end

  test "errors hash is empty on full success" do
    result = PropertyDataSyncService.call(case_number: "2026타경10001")
    assert_empty result.errors
  end
end
```

- [ ] **Step 2: Rewrite PropertyDataSyncService**

`app/services/property_data_sync_service.rb`:
```ruby
class PropertyDataSyncService
  Result = Data.define(:court_data, :building_data, :registry_data, :errors, :property)

  def self.call(case_number:, user: nil, with_detail: false)
    new(case_number:, user:, with_detail:).call
  end

  def initialize(case_number:, user: nil, with_detail: false)
    @case_number = case_number
    @user = user
    @with_detail = with_detail
  end

  def call
    errors = {}

    court_data = fetch_source(:court_auction, errors, :court) do |config|
      adapter = CourtAuctionAdapter.for(config)
      if @with_detail && adapter.respond_to?(:fetch_data_with_detail)
        adapter.fetch_data_with_detail(case_number: @case_number)
      else
        adapter.fetch_data(case_number: @case_number)
      end
    end

    building_data = fetch_source(:data_go_kr, errors, :building) do |config|
      BuildingLedgerAdapter.for(config).fetch_data(case_number: @case_number)
    end

    registry_data = fetch_source_by_category(:registry, errors, :registry) do |config|
      RegistryTranscriptAdapter.for(config).fetch_data(case_number: @case_number)
    end

    property = persist_property(court_data, building_data, registry_data) if court_data

    Result.new(
      court_data: court_data,
      building_data: building_data,
      registry_data: registry_data,
      errors: errors,
      property: property
    )
  end

  private

  def fetch_source(provider_name, errors, error_key)
    config = CredentialResolver.new(user: @user, provider_name: provider_name).resolve
    yield(config)
  rescue DataProvider::Error => e
    errors[error_key] = e
    nil
  end

  def fetch_source_by_category(category, errors, error_key)
    config = CredentialResolver.new(user: @user, category: category).resolve
    yield(config)
  rescue DataProvider::Error => e
    errors[error_key] = e
    nil
  end

  def persist_property(court_data, building_data, registry_data)
    property = Property.find_or_initialize_by(case_number: @case_number)

    # Set properties columns from court_data
    property.assign_attributes(
      case_type: court_data[:case_type],
      claim_amount: court_data[:claim_amount],
      property_type: court_data[:property_type],
      property_usage_code: court_data[:property_usage_code],
      status: court_data[:status],
      address: court_data[:address],
      sido: court_data[:sido],
      sigungu: court_data[:sigungu],
      dong: court_data[:dong],
      building_name: court_data[:building_name],
      building_detail: court_data[:building_detail],
      building_structure: court_data[:building_structure],
      exclusive_area: court_data[:exclusive_area],
      land_category: court_data[:land_category],
      appraisal_price: court_data[:appraisal_price],
      min_bid_price: court_data[:min_bid_price],
      failed_bid_count: court_data[:failed_bid_count],
      view_count: court_data[:view_count],
      interest_count: court_data[:interest_count],
      latitude: court_data[:latitude],
      longitude: court_data[:longitude],
      special_conditions_code: court_data[:special_conditions_code],
      remarks: court_data[:remarks],
      raw_data: {
        building_ledger: building_data&.deep_stringify_keys,
        registry_transcript: registry_data&.deep_stringify_keys
      }.compact
    )
    property.save!

    # Sale detail (1:1)
    if court_data[:non_extinguished_rights] || court_data[:senior_mortgage_basis]
      detail = property.sale_detail || property.build_sale_detail
      detail.assign_attributes(
        non_extinguished_rights: court_data[:non_extinguished_rights],
        superficies_details: court_data[:superficies_details],
        specification_remarks: court_data[:specification_remarks],
        senior_mortgage_basis: court_data[:senior_mortgage_basis],
        goods_remarks: court_data[:goods_remarks],
        dividend_demand_deadline: court_data[:dividend_demand_deadline],
        share_description: court_data[:share_description],
        price_round_1: court_data[:price_round_1],
        price_round_2: court_data[:price_round_2],
        price_round_3: court_data[:price_round_3],
        price_round_4: court_data[:price_round_4]
      )
      detail.save!
    end

    # Auction schedules (1:N) — replace all
    if court_data[:auction_schedules].present?
      property.auction_schedules.destroy_all
      court_data[:auction_schedules].each do |s|
        property.auction_schedules.create!(s)
      end
    end

    # Land details (1:N) — replace all
    if court_data[:land_details].present?
      property.land_details.destroy_all
      court_data[:land_details].each do |l|
        property.land_details.create!(l)
      end
    end

    # Appraisal points (1:N) — replace all
    if court_data[:appraisal_points].present?
      property.appraisal_points.destroy_all
      court_data[:appraisal_points].each do |p|
        property.appraisal_points.create!(p)
      end
    end

    property
  end
end
```

- [ ] **Step 3: Run tests**

Run: `bin/rails test test/services/property_data_sync_service_test.rb`
Expected: All pass.

- [ ] **Step 4: Commit**

```bash
git add app/services/property_data_sync_service.rb test/services/property_data_sync_service_test.rb
git commit -m "feat: rewrite PropertyDataSyncService for normalized schema"
```

---

### Task 5: InspectionRunner Rewrite

**Files:**
- Modify: `app/services/inspection_runner.rb`
- Modify: `test/services/inspection_runner_test.rb`

- [ ] **Step 1: Write tests**

`test/services/inspection_runner_test.rb`:
```ruby
require "test_helper"

class InspectionRunnerTest < ActiveSupport::TestCase
  setup do
    @safe_property = properties(:safe_apartment)
    @risky_property = properties(:risky_villa)
    @user = users(:guest)
  end

  test "creates InspectionResult for each InspectionItem" do
    results = InspectionRunner.call(property: @safe_property, user: @user)
    assert_equal InspectionItem.count, results.size
  end

  test "detects non_extinguished_rights risk from sale_detail" do
    InspectionRunner.call(property: @risky_property, user: @user)
    item = InspectionItem.find_by(code: "rights-002")
    return unless item
    result = InspectionResult.find_by(property: @risky_property, inspection_item: item, user: @user)
    assert_not_nil result
    assert result.auto?
    assert result.has_risk
  end

  test "detects lien from remarks" do
    InspectionRunner.call(property: @risky_property, user: @user)
    item = InspectionItem.find_by(code: "rights-011")
    return unless item
    result = InspectionResult.find_by(property: @risky_property, inspection_item: item, user: @user)
    assert_not_nil result
    assert result.auto?
    assert result.has_risk
  end

  test "safe property has no non_extinguished_rights risk" do
    InspectionRunner.call(property: @safe_property, user: @user)
    item = InspectionItem.find_by(code: "rights-002")
    return unless item
    result = InspectionResult.find_by(property: @safe_property, inspection_item: item, user: @user)
    assert_not_nil result
    assert result.auto?
    assert_not result.has_risk
  end

  test "is idempotent" do
    InspectionRunner.call(property: @safe_property, user: @user)
    count_after_first = InspectionResult.where(property: @safe_property, user: @user).count
    InspectionRunner.call(property: @safe_property, user: @user)
    count_after_second = InspectionResult.where(property: @safe_property, user: @user).count
    assert_equal count_after_first, count_after_second
  end

  test "does not overwrite manual answers on re-run" do
    InspectionRunner.call(property: @safe_property, user: @user)
    item = InspectionItem.ordered.find { |i| InspectionRunner::DETECTION_RULES[i.code].nil? }
    return unless item
    result = InspectionResult.find_by(property: @safe_property, inspection_item: item, user: @user)
    result.update!(source_type: "manual", has_risk: true, resolvable: true)

    InspectionRunner.call(property: @safe_property, user: @user)
    result.reload
    assert result.manual?
    assert result.has_risk
  end
end
```

- [ ] **Step 2: Rewrite InspectionRunner**

`app/services/inspection_runner.rb`:
```ruby
class InspectionRunner
  LIEN_PATTERN = /유치권/
  SUPERFICIES_PATTERN = /법정지상권/
  WALL_PATTERN = /벽체|구조변경|불법.*증축|불법.*개축/

  DETECTION_RULES = {
    # 매각물건명세서 tab — reads from property + sale_detail columns
    "rights-002" => ->(p) {
      text = p.sale_detail&.non_extinguished_rights
      return nil if text.nil? && p.sale_detail.nil?
      text.present?
    },
    "rights-011" => ->(p) {
      combined = [
        p.remarks,
        p.sale_detail&.specification_remarks,
        p.sale_detail&.goods_remarks
      ].compact.join("\n")
      combined.match?(LIEN_PATTERN) || combined.match?(SUPERFICIES_PATTERN)
    },
    "rights-005" => ->(p) {
      nil # use_approval not available from court auction site
    },
    "rights-003" => ->(p) {
      nil # tenants not available from court auction site
    },
    "rights-006" => ->(p) {
      nil # tenants not available
    },
    "rights-014" => ->(p) {
      nil # tenants not available
    },
    "property-002" => ->(p) {
      combined = [
        p.remarks,
        p.sale_detail&.specification_remarks,
        p.sale_detail&.goods_remarks
      ].compact.join("\n")
      return nil if combined.blank? && p.sale_detail.nil?
      combined.match?(WALL_PATTERN) ? true : false
    },
    "rights-019" => ->(p) {
      cat = p.land_category
      return nil if cat.nil?
      cat != "전유" # true = separate land registry = risk
    },
    "rights-020" => ->(p) {
      combined = [
        p.remarks,
        p.sale_detail&.specification_remarks,
        p.sale_detail&.goods_remarks
      ].compact.join("\n")
      return nil if combined.blank? && p.sale_detail.nil?
      combined.match?(LIEN_PATTERN) ? true : false
    },
    "resale-003" => ->(p) {
      floor = p.building_detail
      return nil if floor.blank?
      floor.match?(/지하|반지하/) && !floor.match?(/지상/)
    },

    # 등기부등본 tab — still reads from raw_data (separate provider)
    "rights-001" => ->(p) { p.raw_data&.dig("registry_transcript", "provisional_disposition_senior") == true },
    "rights-007" => ->(p) { p.raw_data&.dig("registry_transcript", "notice_registration") == true },
    "rights-008" => ->(p) { p.raw_data&.dig("registry_transcript", "senior_tax_seizure") == true },

    # 건축물대장 tab — still reads from raw_data (separate provider)
    "property-004" => ->(p) { p.raw_data&.dig("building_ledger", "violation_flag") == true },
    "property-005" => ->(p) { p.raw_data&.dig("building_ledger", "usage_type") == "사무소" },
    "resale-002" => ->(p) { (p.raw_data&.dig("building_ledger", "parking_per_unit") || 99) < 0.5 },

    # 온라인조회 tab
    "property-001" => ->(p) {
      p.sale_detail&.share_description.present?
    }
  }.freeze

  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    @property.sale_detail # eager load

    InspectionItem.ordered.map do |item|
      result = @property.inspection_results.find_or_initialize_by(inspection_item: item, user: @user)

      rule = DETECTION_RULES[item.code]
      if rule.nil?
        unless result.persisted? && result.source_type.present?
          result.assign_attributes(source_type: nil, has_risk: nil)
        end
      else
        detected = begin
          rule.call(@property)
        rescue
          nil
        end
        if detected.nil?
          unless result.persisted? && result.source_type.present?
            result.assign_attributes(source_type: nil, has_risk: nil)
          end
        else
          result.assign_attributes(source_type: "auto", has_risk: detected)
        end
      end

      result.save!
      result
    end
  end
end
```

- [ ] **Step 3: Run tests**

Run: `bin/rails test test/services/inspection_runner_test.rb`
Expected: All pass.

- [ ] **Step 4: Commit**

```bash
git add app/services/inspection_runner.rb test/services/inspection_runner_test.rb
git commit -m "feat: rewrite InspectionRunner to use structured columns"
```

---

### Task 6: Update SourceDocViewerComponent and Controller

**Files:**
- Modify: `app/components/source_doc_viewer_component.rb`
- Modify: `app/components/source_doc_viewer_component.html.erb`
- Modify: `app/controllers/properties_controller.rb`

- [ ] **Step 1: Update SourceDocViewerComponent**

`app/components/source_doc_viewer_component.rb`:
```ruby
class SourceDocViewerComponent < ViewComponent::Base
  def initialize(property:)
    @property = property
    @sale_detail = property.sale_detail
    @registry_transcript = property.raw_data&.dig("registry_transcript") || {}
  end
end
```

`app/components/source_doc_viewer_component.html.erb`:
```erb
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

  <div data-source-doc-tracker-target="panel" data-doc-type="court_auction"
       class="rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4 text-sm font-mono leading-relaxed text-slate-700 dark:text-slate-300">
    <div class="font-semibold text-slate-900 dark:text-slate-100 mb-2">매각물건명세서 주요 내용</div>
    <% if @sale_detail %>
      <p>• 비고란: <%= @property.remarks.presence || "해당사항 없음" %></p>
      <p>• 소멸되지 아니하는 것: <%= @sale_detail.non_extinguished_rights.presence || "해당 없음" %></p>
      <p>• 말소기준권리: <%= @sale_detail.senior_mortgage_basis.presence || "미확인" %></p>
      <p>• 배당요구종기: <%= @sale_detail.dividend_demand_deadline&.strftime("%Y.%m.%d") || "미확인" %></p>
      <% if @sale_detail.specification_remarks.present? %>
        <p>• 명세서 비고: <%= @sale_detail.specification_remarks %></p>
      <% end %>
      <% if @sale_detail.share_description.present? %>
        <p>• 지분매각: <%= @sale_detail.share_description %></p>
      <% end %>
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

  <div class="rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-700 px-3 py-2 text-sm text-red-800 dark:text-red-200">
    ⚠️ 반드시 매각물건명세서 비고란을 직접 확인하세요. 본 서비스는 분석 결과의 정확성을 보증하지 않습니다.
  </div>
</div>
```

- [ ] **Step 2: Update PropertiesController search**

In `app/controllers/properties_controller.rb`, change line 10 from:
```ruby
"properties.case_number LIKE :q OR properties.address LIKE :q OR properties.court_name LIKE :q",
```
to:
```ruby
"properties.case_number LIKE :q OR properties.address LIKE :q OR properties.building_name LIKE :q",
```

- [ ] **Step 3: Commit**

```bash
git add app/components/ app/controllers/properties_controller.rb
git commit -m "feat: update component and controller for structured schema"
```

---

### Task 7: Seed Data and Final Verification

**Files:**
- Modify: `db/seeds.rb`
- Modify: `db/seeds/real_properties.json`

- [ ] **Step 1: Update seeds.rb property section**

Replace the properties seeding section in `db/seeds.rb` (lines 103-124):

```ruby
puts "Seeding properties from live court auction data..."
guest = User.find_by!(email: "guest@auction.local")
Property.destroy_all
real_properties = JSON.parse(File.read(Rails.root.join("db/seeds/real_properties.json")))
real_properties.each do |attrs|
  property = Property.find_or_initialize_by(case_number: attrs["case_number"])
  property.assign_attributes(
    case_type: attrs["case_type"],
    claim_amount: attrs["claim_amount"],
    property_type: attrs["property_type"],
    property_usage_code: attrs["property_usage_code"],
    status: attrs.fetch("status", "진행중"),
    address: attrs["address"],
    sido: attrs["sido"],
    sigungu: attrs["sigungu"],
    dong: attrs["dong"],
    building_name: attrs["building_name"],
    building_detail: attrs["building_detail"],
    building_structure: attrs["building_structure"],
    exclusive_area: attrs["exclusive_area"],
    land_category: attrs["land_category"],
    appraisal_price: attrs["appraisal_price"],
    min_bid_price: attrs["min_bid_price"],
    failed_bid_count: attrs["failed_bid_count"],
    view_count: attrs.fetch("view_count", 0),
    interest_count: attrs.fetch("interest_count", 0),
    latitude: attrs["latitude"],
    longitude: attrs["longitude"],
    special_conditions_code: attrs["special_conditions_code"],
    remarks: attrs["remarks"]
  )
  property.save!

  # Sale detail
  if attrs["sale_detail"]
    sd = attrs["sale_detail"]
    detail = property.sale_detail || property.build_sale_detail
    detail.assign_attributes(
      non_extinguished_rights: sd["non_extinguished_rights"],
      superficies_details: sd["superficies_details"],
      specification_remarks: sd["specification_remarks"],
      senior_mortgage_basis: sd["senior_mortgage_basis"],
      goods_remarks: sd["goods_remarks"],
      dividend_demand_deadline: sd["dividend_demand_deadline"],
      share_description: sd["share_description"],
      price_round_1: sd["price_round_1"],
      price_round_2: sd["price_round_2"],
      price_round_3: sd["price_round_3"],
      price_round_4: sd["price_round_4"]
    )
    detail.save!
  end

  # Auction schedules
  (attrs["auction_schedules"] || []).each do |s|
    property.auction_schedules.create!(
      schedule_date: s["schedule_date"],
      schedule_time: s["schedule_time"],
      bid_start_date: s["bid_start_date"],
      bid_end_date: s["bid_end_date"],
      place: s["place"],
      schedule_type: s["schedule_type"],
      result_code: s["result_code"],
      min_price: s["min_price"],
      sale_amount: s["sale_amount"]
    )
  end

  # Land details
  (attrs["land_details"] || []).each do |l|
    property.land_details.create!(
      land_type: l["land_type"],
      land_area: l["land_area"],
      land_category: l["land_category"],
      share_ratio: l["share_ratio"],
      address: l["address"],
      lot_number: l["lot_number"]
    )
  end

  # Appraisal points
  (attrs["appraisal_points"] || []).each do |p|
    property.appraisal_points.create!(
      item_code: p["item_code"],
      content: p["content"]
    )
  end

  guest.user_properties.find_or_create_by!(property: property)
end
puts "  -> #{Property.count} properties (#{guest.user_properties.count} linked to guest)"
```

- [ ] **Step 2: Update real_properties.json structure**

The JSON needs to be restructured to match the new schema. Each property should have nested `sale_detail`, `auction_schedules`, `land_details`, `appraisal_points` objects. This requires re-collecting data from the court auction site using the Playwright approach from earlier in this conversation, mapping fields to the new column names.

For the first property as example structure:
```json
{
  "case_number": "2024타경1423",
  "case_type": "부동산임의경매",
  "claim_amount": 512602740,
  "property_type": "아파트",
  "property_usage_code": "01",
  "address": "서울특별시 강남구 압구정로 309 91동 5층510호 (압구정동,현대아파트)",
  "sido": "서울특별시",
  "sigungu": "강남구",
  "dong": "압구정동",
  "building_name": "현대아파트",
  "building_detail": "91동 5층510호",
  "building_structure": "철근콩크리트조 111.50㎡",
  "exclusive_area": 111.5,
  "land_category": "전유",
  "appraisal_price": 4000000000,
  "min_bid_price": 4000000000,
  "failed_bid_count": 0,
  "view_count": 0,
  "interest_count": 0,
  "latitude": 37.0,
  "longitude": 127.0,
  "special_conditions_code": "",
  "remarks": "",
  "sale_detail": {
    "non_extinguished_rights": null,
    "superficies_details": null,
    "specification_remarks": null,
    "senior_mortgage_basis": "1999.5.27. 근저당권",
    "goods_remarks": null,
    "dividend_demand_deadline": "2024-07-01",
    "share_description": null,
    "price_round_1": 4000000000,
    "price_round_2": null,
    "price_round_3": null,
    "price_round_4": null
  },
  "auction_schedules": [],
  "land_details": [],
  "appraisal_points": []
}
```

All 20 properties must follow this structure. Generate programmatically by combining existing `real_properties.json` data with the detail data collected via Playwright earlier.

- [ ] **Step 3: Add raw_data column back for building_ledger/registry_transcript**

The `properties` table still needs a `raw_data` column for `building_ledger` and `registry_transcript` data that comes from separate adapters. Add this to the migration if not already present, or keep it. Since the migration in Task 1 removes `raw_data`, add it back:

In the migration, after removing raw_data, add:
```ruby
add_column :properties, :raw_data, :json
```

This keeps raw_data for non-court-auction adapter data only.

- [ ] **Step 4: Run seed and full test suite**

```bash
bin/rails db:reset
bin/rails test
```
Expected: All seeds succeed, all tests pass.

- [ ] **Step 5: Commit**

```bash
git add db/seeds.rb db/seeds/real_properties.json
git commit -m "feat: update seeds for normalized property schema"
```

---

### Task 8: Run Full Test Suite and Fix Remaining Failures

- [ ] **Step 1: Run all tests**

```bash
bin/rails test
```

- [ ] **Step 2: Fix any remaining failures**

Common issues to check:
- `RightsAnalysisService` still reads `raw_data["registry_transcript"]` — should work since we kept `raw_data` for non-court-auction data
- Any view/component that references `property.court_name` — removed column, search for references
- `MockCourtAuctionAdapter` return format may need updating to match new field names

- [ ] **Step 3: Run rubocop**

```bash
bin/rubocop -a
```

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "fix: resolve remaining test failures after schema redesign"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Database migration (5 tables) | 1 migration |
| 2 | Models + fixtures | 5 models, 5 fixtures |
| 3 | ResponseParser rewrite | 1 adapter, 1 test |
| 4 | PropertyDataSyncService rewrite | 1 service, 1 test |
| 5 | InspectionRunner rewrite | 1 service, 1 test |
| 6 | Component + controller update | 3 files |
| 7 | Seed data restructure | 2 files |
| 8 | Full suite verification | Fix remaining |
