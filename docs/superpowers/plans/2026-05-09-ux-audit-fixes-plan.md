# UX Audit Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triage and remediate 89 UX/UX-correctness issues found in the 2026-05-09 dual-persona UX audit (45 beginner + 44 expert findings) across three release phases, anchored on the 2026-05-19 launch deadline.

**Architecture:** Phase-staged remediation. Phase A blocks the 2026-05-19 single-server launch (legal, data-integrity, false-safety, and core onboarding gates). Phase B raises retention quality in the 2-4 weeks after launch (clarity, mobile, expert workflow). Phase C clears Medium/Low polish over 4-12 weeks. Every fix is anchored to a concrete file, follows Rails 8 + Hotwire + ViewComponent + Tailwind conventions, and is verified via Minitest (system / service / component tests). Tidy First: structural changes (extractions, renames, table-only edits) ship in separate commits from behavior changes.

**Tech Stack:** Rails 8.0, Ruby 3.3, Hotwire (Turbo + Stimulus), ViewComponent, Tailwind CSS, Minitest + Capybara, SQLite (test) / PostgreSQL (prod), Anthropic SDK (LLM adapters), DSL seeds (db/seeds/*.json).

**Inputs (sources of truth):**
- `docs/audits/2026-05-09-ux-audit-beginner.md` — 45 issues, beginner persona
- `docs/audits/2026-05-09-ux-audit-expert.md` — 44 issues, veteran investor persona

**Audit IDs in this plan:** `B-NN` = beginner-audit row N. `E-NN` = expert-audit row N. Cross-references in parentheses, e.g. `(B-1, E-36)` = beginner row 1 + expert row 36.

---

## Phase Summary

| Phase | Window | Items | Severity | Posture |
|-------|--------|-------|----------|---------|
| **A** Pre-launch Critical | 2026-05-09 → 2026-05-18 (10 days) | 13 grouped tasks | All Critical + 2 Beginner Top-5 | Block launch if any item fails. TDD discipline strict. |
| **B** Post-launch Wave 1 | 2026-05-20 → 2026-06-19 (≈4 weeks) | 30 tasks | High | Retention. Ship weekly. |
| **C** Post-launch Wave 2 | 2026-06-20 → 2026-08-31 (≈10 weeks) | ~46 issues | Medium / Low | Polish + expert features. Backlog form. |

Total mapped: **89 audit findings** (deduped from raw 89 → 78 unique fixes; some Beg+Exp pairs collapse).

---

## File Structure (touched / created across all phases)

**New files:**
- `app/views/home/landing.html.erb` — pre-login landing (A9)
- `app/components/home/landing_component.{rb,html.erb}` — landing hero + CTAs (A9)
- `app/views/eviction_guide/steps/_detail.html.erb` — step detail partial (A11)
- `app/views/eviction_guide/branches/_detail.html.erb` — branch detail partial (A11)
- `app/components/inspection/term_glossary_component.{rb,html.erb}` — inline glossary tooltip (A12)
- `app/components/llm_data_disclosure_component.{rb,html.erb}` — what-is-sent panel (A13)
- `db/seeds/legal_terms.md` + `db/seeds/legal_privacy.md` — legal text source (A1)
- `db/migrate/<ts>_add_dividend_requested_to_inspection_results.rb` — schema for E-8 fix
- `db/migrate/<ts>_add_co_owner_priority_purchase_to_checklist_items.rb` — seed migration helper for E-4

**Modified files (summary):**
- `app/controllers/home_controller.rb` — landing routing (A9)
- `app/controllers/properties_controller.rb` — case_number-first PDF flow (A2)
- `app/views/legal/{terms,privacy}.html.erb` — replace placeholder (A1)
- `app/views/onboardings/step{1,2,3}.html.erb` — terminology + tooltips (A10, B-2/3/4)
- `app/views/inspections/grades/show.html.erb` — incomplete-safe gate banner (A7)
- `app/views/eviction_guide/steps/show.html.erb`, `branches/show.html.erb` — replace stub with detail partial (A11)
- `app/components/bid_opinion_component.rb` — remove advisory phrasing (A8)
- `app/services/inspection/rights_validator.rb` — same-day move-in flag (A5), per-right inheritance branching (A4)
- `app/services/pdf_analysis_service.rb` — case_number conflict guard, no placeholder Property (A2)
- `app/services/llm/pdf_prompt_builder.rb` — add `dividend_requested`, `source_doc/page/quote` fields (A3, B-19/E-19)
- `app/services/inspection/inspection_rating_service.rb` — gate `:safe` behind priority="상" coverage (A7)
- `db/seeds/checklist_items_summary.json` — priority bump (rights-021), 5 new items (E-4)
- `app/views/analyses/new.html.erb`, `_form.html.erb` — disable AI-auto tab + data-disclosure panel (A13)

**Test files (created / modified):**
- `test/system/landing_test.rb` (A9)
- `test/system/legal_pages_test.rb` (A1)
- `test/system/case_number_first_flow_test.rb` (A2)
- `test/services/inspection/rights_validator_test.rb` (A4, A5 additions)
- `test/services/pdf_analysis_service_test.rb` (A2 additions)
- `test/services/inspection/inspection_rating_service_test.rb` (A7)
- `test/services/inspection/pdf_prompt_builder_test.rb` (A3 additions)
- `test/components/bid_opinion_component_test.rb` (A8)
- `test/system/eviction_step_detail_test.rb` (A11)
- `test/system/checklist_glossary_test.rb` (A12)
- `test/system/llm_data_disclosure_test.rb` (A13)

---

# PHASE A — Pre-launch Critical (2026-05-09 → 2026-05-18)

**Acceptance gate:** All 13 tasks below merged to `main` and verified on staging before 2026-05-18 EOD. If any item slips, escalate to delay launch — these are launch-blockers.

**Suggested sequence (parallelizable streams):**

1. **Legal stream (1 owner):** A1 (약관/방침)
2. **Data-integrity stream (1 owner):** A2 → A3 → A4 → A5 → A6 → A7 (sequential, share rights pipeline)
3. **Frontend-trust stream (1 owner):** A8, A9, A10, A13 (parallel after A1 ships terms)
4. **Content stream (1 owner):** A11, A12 (parallel)

---

### Task A1: 정식 이용약관 / 개인정보처리방침 작성 (Beg#29 + Exp#36)

**Category:** 법적 책임 / 출시 차단
**Effort:** M (4-6h, plus legal review time outside engineering)
**Dependencies:** Legal team draft (out-of-band). Engineering wires content + consent UI.

**Files:**
- Create: `db/seeds/legal_terms.md` (canonical Korean terms text)
- Create: `db/seeds/legal_privacy.md` (canonical Korean privacy text)
- Modify: `app/views/legal/terms.html.erb` — render content from seed
- Modify: `app/views/legal/privacy.html.erb` — render content from seed
- Modify: `app/views/users/_oauth_consent.html.erb` (or wherever the consent checkbox lives) — link target lines reference both pages
- Test: `test/system/legal_pages_test.rb`

- [ ] **Step 1: Confirm legal copy is delivered (out-of-band)**

Block engineering until legal returns final Korean text for both documents. Required sections per 개인정보보호법: 수집·이용 목적, 항목, 보유기간, 제3자 제공(LLM API 포함 — Anthropic/OpenAI/Google), 파기 절차, 정보주체 권리, DPO 연락처. Required terms sections: 서비스 정의, AI 분석 결과의 한계 및 면책, 사용자 책임, 분쟁 해결, 약관 변경 절차.

- [ ] **Step 2: Write the failing test**

```ruby
# test/system/legal_pages_test.rb
require "application_system_test_case"

class LegalPagesTest < ApplicationSystemTestCase
  test "terms page renders full content with required sections" do
    visit terms_path
    assert_text "이용약관"
    assert_text "AI 분석 결과의 한계 및 면책"
    assert_text "사용자 책임"
    refute_text "정식 출시 전 작성 중"
  end

  test "privacy page renders full content with required sections" do
    visit privacy_path
    assert_text "개인정보처리방침"
    assert_text "수집하는 개인정보 항목"
    assert_text "보유 및 이용 기간"
    assert_text "외부 LLM API 제공사"
    refute_text "정식 출시 전 작성 중"
  end
end
```

- [ ] **Step 3: Run test → expect failure**

Run: `bin/rails test test/system/legal_pages_test.rb`
Expected: FAIL — current views still show "정식 출시 전 작성 중".

- [ ] **Step 4: Add seeds and view loaders**

```erb
<%# app/views/legal/terms.html.erb %>
<article class="prose mx-auto py-8 max-w-3xl">
  <%= raw markdown(Rails.root.join("db/seeds/legal_terms.md").read) %>
</article>
```

```erb
<%# app/views/legal/privacy.html.erb %>
<article class="prose mx-auto py-8 max-w-3xl">
  <%= raw markdown(Rails.root.join("db/seeds/legal_privacy.md").read) %>
</article>
```

If `markdown` helper does not exist, add a thin one in `app/helpers/markdown_helper.rb`:

```ruby
module MarkdownHelper
  def markdown(text)
    @md_renderer ||= Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(safe_links_only: true), tables: true, fenced_code_blocks: true)
    @md_renderer.render(text).html_safe
  end
end
```

Add `gem "redcarpet"` to Gemfile if not present, then `bundle install`.

- [ ] **Step 5: Place legal copy into seed files**

Paste the lawyer-approved Korean text into `db/seeds/legal_terms.md` and `db/seeds/legal_privacy.md`. Do not abbreviate.

- [ ] **Step 6: Run tests → expect pass**

Run: `bin/rails test test/system/legal_pages_test.rb`
Expected: PASS.

- [ ] **Step 7: Commit (structural — empty content stubs first if legal copy is late)**

```bash
git add db/seeds/legal_terms.md db/seeds/legal_privacy.md \
        app/views/legal/terms.html.erb app/views/legal/privacy.html.erb \
        app/helpers/markdown_helper.rb Gemfile Gemfile.lock \
        test/system/legal_pages_test.rb
git commit -m "feat(legal): render terms and privacy from seed markdown

Replaces 'under construction' placeholders with full Korean legal text
sourced from db/seeds/legal_*.md. Wires markdown helper via redcarpet."
```

---

### Task A2: PDF 분석 시 case_number 사용자 입력 강제 + LLM 추출 충돌 검증 (Exp#7, related E-15)

**Category:** 데이터 무결성 / Critical
**Effort:** L (6-8h)
**Dependencies:** None (touches `pdf_analysis_service.rb` + properties controller)

**Files:**
- Modify: `app/services/pdf_analysis_service.rb` lines 90-150 — remove placeholder Property creation, raise on conflict
- Modify: `app/controllers/analyses_controller.rb` — require property_id (existing Property) param before PDF intake
- Modify: `app/views/analyses/new.html.erb` — flow: pick existing Property OR enter case_number+court first
- Test: `test/services/pdf_analysis_service_test.rb`, `test/system/case_number_first_flow_test.rb`

- [ ] **Step 1: Write failing test for "no placeholder Property"**

```ruby
# test/services/pdf_analysis_service_test.rb (add)
test "raises CaseNumberMissingError when no property_id given and LLM did not extract case_number" do
  user = users(:one)
  service = PdfAnalysisService.new(user: user, file: fixture_file("blank.pdf"))

  Llm::Anthropic.stub :analyze, { "metadata" => {} } do
    assert_raises(PdfAnalysisService::CaseNumberMissingError) { service.call }
  end

  assert_equal 0, Property.where("case_number LIKE 'PDF-%'").count
end

test "raises CaseNumberMismatchError when user-supplied case_number differs from LLM extraction" do
  user = users(:one)
  property = properties(:case_2026_1234)  # case_number: "2026타경1234"
  service = PdfAnalysisService.new(user: user, file: fixture_file("blank.pdf"), property_id: property.id)

  Llm::Anthropic.stub :analyze, { "metadata" => { "case_number" => "2026타경9999" } } do
    assert_raises(PdfAnalysisService::CaseNumberMismatchError) { service.call }
  end
end
```

- [ ] **Step 2: Run tests → expect failure**

Run: `bin/rails test test/services/pdf_analysis_service_test.rb`
Expected: FAIL — current code creates `PDF-{hex}` placeholder Property.

- [ ] **Step 3: Modify service**

```ruby
# app/services/pdf_analysis_service.rb
class PdfAnalysisService
  class CaseNumberMissingError < StandardError; end
  class CaseNumberMismatchError < StandardError; end

  def resolve_property(metadata)
    if @property_id.present?
      property = Property.find(@property_id)
      llm_case = metadata["case_number"].presence
      if llm_case && normalize_case(llm_case) != normalize_case(property.case_number)
        raise CaseNumberMismatchError,
              "PDF에서 추출된 사건번호(#{llm_case})가 선택한 물건(#{property.case_number})과 다릅니다."
      end
      property
    else
      llm_case = metadata["case_number"].presence
      raise CaseNumberMissingError, "사건번호를 먼저 입력해 주세요." if llm_case.blank?
      Property.find_by!(case_number: normalize_case(llm_case))
    end
  end

  private

  def normalize_case(s)
    s.to_s.gsub(/\s+/, "").downcase
  end
end
```

Remove the previous `case_number: "PDF-#{SecureRandom.hex(4)}"` branch entirely.

- [ ] **Step 4: Run service tests → expect pass**

Run: `bin/rails test test/services/pdf_analysis_service_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit (behavior change)**

```bash
git add app/services/pdf_analysis_service.rb test/services/pdf_analysis_service_test.rb
git commit -m "fix(pdf): require property/case_number before PDF analysis

Removes 'PDF-{hex}' placeholder Property creation. Raises explicit
errors when (a) no case_number provided and LLM cannot extract one,
(b) user-supplied case_number conflicts with LLM extraction.
Prevents cross-user data overwrites (Exp#7)."
```

- [ ] **Step 6: Write failing system test for new flow**

```ruby
# test/system/case_number_first_flow_test.rb
require "application_system_test_case"

class CaseNumberFirstFlowTest < ApplicationSystemTestCase
  setup { sign_in_as(users(:one)) }

  test "PDF upload page requires picking an existing property" do
    visit new_analysis_path
    assert_text "분석할 물건을 먼저 선택하세요"
    assert_no_button "PDF 업로드", disabled: false
  end

  test "after picking property, PDF upload becomes enabled" do
    property = properties(:case_2026_1234)
    visit new_analysis_path
    select property.case_number, from: "분석 대상 물건"
    assert_button "PDF 업로드", disabled: false
  end
end
```

- [ ] **Step 7: Update `new.html.erb` flow**

```erb
<%# app/views/analyses/new.html.erb %>
<%= form_with url: analyses_path, method: :post, multipart: true, data: { controller: "analysis-form" } do |f| %>
  <div class="mb-6">
    <%= f.label :property_id, "분석 대상 물건", class: "block font-medium mb-2" %>
    <%= f.collection_select :property_id, current_user.user_properties.includes(:property).map(&:property), :id, :case_number, { prompt: "분석할 물건을 먼저 선택하세요" }, data: { analysis_form_target: "propertySelect", action: "change->analysis-form#togglePdf" } %>
  </div>
  <div class="mb-6">
    <%= f.label :pdf, "매각물건명세서/등기부등본 PDF" %>
    <%= f.file_field :pdf, data: { analysis_form_target: "pdfInput" }, disabled: true %>
  </div>
  <%= f.submit "PDF 업로드", disabled: true, class: "btn-primary", data: { analysis_form_target: "submitBtn" } %>
<% end %>
```

Add `app/javascript/controllers/analysis_form_controller.js` (Stimulus) that flips `disabled` on the file input and submit button when a property is selected.

- [ ] **Step 8: Run system test → pass; commit**

```bash
bin/rails test test/system/case_number_first_flow_test.rb
git add app/views/analyses/new.html.erb app/javascript/controllers/analysis_form_controller.js test/system/case_number_first_flow_test.rb
git commit -m "feat(analyses): require property selection before PDF upload"
```

---

### Task A3: dividend_requested 필드 prompt/code 정합성 회복 (Exp#8)

**Category:** LLM 신뢰도 / Critical
**Effort:** S (2-3h)
**Dependencies:** None

**Files:**
- Modify: `app/services/llm/pdf_prompt_builder.rb` — add `dividend_requested` to tenants schema in SYSTEM_PROMPT
- Modify: `app/services/llm/f02_data_extractor.rb` line 41 — keep read; ensure default
- (Optional) DB: `inspection_results` already stores raw response — no migration needed if we keep it in JSON
- Test: `test/services/inspection/pdf_prompt_builder_test.rb`

- [ ] **Step 1: Write failing test**

```ruby
test "tenants schema in SYSTEM_PROMPT requires dividend_requested field" do
  prompt = Llm::PdfPromptBuilder::SYSTEM_PROMPT
  assert_match(/dividend_requested/, prompt, "tenants schema must include dividend_requested")
  assert_match(/배당요구/, prompt, "prompt must instruct LLM to extract 배당요구 from 매각물건명세서")
end
```

- [ ] **Step 2: Run → expect FAIL**

Run: `bin/rails test test/services/inspection/pdf_prompt_builder_test.rb`
Expected: FAIL.

- [ ] **Step 3: Update prompt**

In `app/services/llm/pdf_prompt_builder.rb`, locate the `tenants` JSON schema section and add:

```text
"dividend_requested": boolean | null  // 매각물건명세서 임차인 표의 "배당요구" 칼럼. 신청=true, 미신청=false, 명시 없음=null
```

Also append to the prompt's instructions:

```text
- 임차인의 dividend_requested는 매각물건명세서 "배당요구일자/배당요구여부" 컬럼을 우선으로 추출. 등기부에는 없으니 명세서가 없는 경우 null 처리.
```

- [ ] **Step 4: Run → expect PASS; commit**

```bash
bin/rails test test/services/inspection/pdf_prompt_builder_test.rb
git add app/services/llm/pdf_prompt_builder.rb test/services/inspection/pdf_prompt_builder_test.rb
git commit -m "fix(llm): add dividend_requested to tenants prompt schema

Code already reads t['dividend_requested'] in f02_data_extractor.rb
and registry_timeline_component, but prompt did not request it,
so value was always nil → '배당요구 ✗' shown unconditionally (Exp#8)."
```

- [ ] **Step 5: Backfill check — ensure existing analyses re-prompt next time**

No migration needed; existing `inspection_results` rows with old null `dividend_requested` show "확인 필요" instead of "✗" — handle in view:

```erb
<%# app/components/registry_timeline_component.html.erb (around line 39) %>
<% if t["dividend_requested"].nil? %>
  <span class="text-zinc-400">확인 필요</span>
<% elsif t["dividend_requested"] %>
  <span class="text-emerald-700">배당요구 ○</span>
<% else %>
  <span class="text-zinc-700">배당요구 ✗</span>
<% end %>
```

Commit: `fix(timeline): show '확인 필요' when dividend_requested is null`.

---

### Task A4: 인수금액 계산 — 권리 유형별 분기 + disclaimer (Exp#2, partial Exp#3)

**Category:** 법률/실무 정확성 / Critical
**Effort:** L (8-10h)
**Dependencies:** A3 (consistent prompt schema)

**Files:**
- Modify: `app/services/inspection/rights_validator.rb` — `calculate_amounts` branching
- Modify: `app/services/llm/pdf_prompt_builder.rb` — require `right_type` enum + `amount_type` field
- Modify: `app/components/rights_analysis_report_component.html.erb` — show "별도 평가 필요" badge + total disclaimer
- Test: `test/services/inspection/rights_validator_test.rb`

**Branching rule:** `extinguished_on_sale=false` rights with `right_type ∈ {가등기, 가처분, 유치권, 법정지상권}` → exclude from `assumed_amount`, surface separately as `unevaluated_rights[]`. `right_type="선순위 세금압류"` → also exclude (배당우선이라 채권액 합산 부적절).

- [ ] **Step 1: Write failing tests**

```ruby
test "유치권 is excluded from assumed_amount and surfaced as unevaluated" do
  result = Inspection::RightsValidator.call(
    base_right_date: "2024-01-01",
    tenants: [],
    rights_timeline: [
      { "right_type" => "근저당", "amount" => 100_000_000, "extinguished_on_sale" => true },
      { "right_type" => "유치권", "amount" => 50_000_000, "extinguished_on_sale" => false }
    ]
  )
  assert_equal 0, result.validated_amounts["assumed_amount"]
  assert_equal 1, result.validated_amounts["unevaluated_rights"].size
  assert_equal "유치권", result.validated_amounts["unevaluated_rights"].first["right_type"]
end

test "선순위 가등기 is unevaluated (소유권 자체 위험)" do
  result = Inspection::RightsValidator.call(
    base_right_date: "2024-01-01",
    tenants: [],
    rights_timeline: [
      { "right_type" => "가등기", "amount" => 0, "extinguished_on_sale" => false, "registered_on" => "2023-01-01" }
    ]
  )
  assert_equal 0, result.validated_amounts["assumed_amount"]
  assert_equal 1, result.validated_amounts["unevaluated_rights"].size
end
```

- [ ] **Step 2: Run → FAIL**

- [ ] **Step 3: Implement branching**

```ruby
# app/services/inspection/rights_validator.rb
UNEVALUATED_TYPES = %w[가등기 가처분 유치권 법정지상권 선순위세금압류].freeze

def calculate_amounts(validated_tenants)
  surviving = @rights_timeline.reject { |r| r["extinguished_on_sale"] }
  unevaluated, summable = surviving.partition { |r| UNEVALUATED_TYPES.include?(r["right_type"].to_s.gsub(/\s+/, "")) }

  assumed = summable.sum { |r| r["amount"].to_i }
  opposing_deposits = validated_tenants.select { |t| t["opposing_power"] }.sum { |t| t["deposit"].to_i }

  {
    "assumed_amount" => assumed,
    "opposing_deposits" => opposing_deposits,
    "total_risk_amount" => assumed + opposing_deposits,
    "unevaluated_rights" => unevaluated,
    "disclaimer" => "추정치이며, 별도 평가 필요 항목이 #{unevaluated.size}건 있습니다. 베테랑/공인중개사 검토를 권장합니다."
  }
end
```

- [ ] **Step 4: Run → PASS**

- [ ] **Step 5: Update report component to show unevaluated list + disclaimer**

```erb
<%# app/components/rights_analysis_report_component.html.erb %>
<% if @amounts["unevaluated_rights"].any? %>
  <div class="rounded border-l-4 border-amber-500 bg-amber-50 p-4 my-4">
    <h3 class="font-semibold text-amber-900">⚠️ 자동 계산 불가 권리 (<%= @amounts["unevaluated_rights"].size %>건)</h3>
    <ul class="mt-2 list-disc pl-6 text-sm">
      <% @amounts["unevaluated_rights"].each do |r| %>
        <li><strong><%= r["right_type"] %></strong> — 별도 평가 필요. 본 도구는 채권액 합산에서 제외했습니다.</li>
      <% end %>
    </ul>
    <p class="mt-2 text-xs text-amber-800"><%= @amounts["disclaimer"] %></p>
  </div>
<% end %>
```

- [ ] **Step 6: Commit**

```bash
git add app/services/inspection/rights_validator.rb \
        app/components/rights_analysis_report_component.html.erb \
        test/services/inspection/rights_validator_test.rb
git commit -m "fix(rights): branch unevaluated right types out of assumed_amount

가등기/가처분/유치권/법정지상권/선순위세금압류는 단순 채권액 합산이
실제 인수금액과 어긋나므로 unevaluated_rights[]로 분리 표시. 보고서에
경고 배너와 disclaimer 추가 (Exp#2)."
```

---

### Task A5: 동일자 전입 — 익일 0시 효력 발생 경고 플래그 (Exp#1)

**Category:** 법률 정확성 / Critical
**Effort:** S (2-3h)
**Dependencies:** None (rights_validator only)

**Files:**
- Modify: `app/services/inspection/rights_validator.rb` lines 33-37 (+ Result struct)
- Modify: `app/components/rights_analysis_report_component.html.erb` — show warning chip per tenant
- Test: `test/services/inspection/rights_validator_test.rb`

- [ ] **Step 1: Write failing test**

```ruby
test "transit on same day as base right yields opposing_power=false but warns" do
  result = Inspection::RightsValidator.call(
    base_right_date: "2024-01-15",
    tenants: [{ "name" => "김임차", "deposit" => 100_000_000, "move_in_date" => "2024-01-15", "confirmed_date" => "2024-01-15" }],
    rights_timeline: []
  )
  tenant = result.validated_tenants.first
  assert_equal false, tenant["opposing_power"]
  assert_equal true, tenant["same_day_warning"]
  assert_match(/익일 0시/, tenant["warning_message"])
end
```

- [ ] **Step 2: Run → FAIL; Step 3: implement**

```ruby
def validate_tenant(tenant)
  move_in = parse_date(tenant["move_in_date"])
  confirmed = parse_date(tenant["confirmed_date"])

  same_day = @base_right_date && move_in && move_in == @base_right_date
  opposing = if @base_right_date && move_in
    move_in < @base_right_date
  else
    false
  end

  has_priority = move_in.present? && confirmed.present?
  eff_date = has_priority ? [ move_in + 1.day, confirmed ].max : nil

  {
    "name" => tenant["name"],
    "deposit" => tenant["deposit"],
    "move_in_date" => tenant["move_in_date"],
    "confirmed_date" => tenant["confirmed_date"],
    "opposing_power" => opposing,
    "same_day_warning" => same_day,
    "warning_message" => same_day ? "전입과 말소기준이 같은 날입니다. 대항력은 익일 0시 효력 발생 원칙상 후순위로 판정했으나, 전입 시각·전입세대열람 등 추가 확인이 필요합니다." : nil,
    "has_priority_repayment" => has_priority,
    "effective_date" => eff_date&.to_s,
    "priority_rank" => nil
  }
end
```

- [ ] **Step 4: Run → PASS; render warning in component**

```erb
<% if t["same_day_warning"] %>
  <div class="ml-2 inline-block rounded bg-orange-100 px-2 py-0.5 text-xs text-orange-900" title="<%= t['warning_message'] %>">
    동일자 전입 — 추가 확인 필요
  </div>
<% end %>
```

- [ ] **Step 5: Commit**

```bash
git add app/services/inspection/rights_validator.rb \
        app/components/rights_analysis_report_component.html.erb \
        test/services/inspection/rights_validator_test.rb
git commit -m "fix(rights): flag same-day move-in as 'requires additional verification'

대항력은 전입 익일 0시 효력 발생. 동일자 전입은 후순위로 판정하되
사용자에게 익일 0시 원칙과 추가 확인 필요를 명시 (Exp#1)."
```

---

### Task A6: 공유자우선매수권 priority 격상 + 5개 누락 시드 항목 추가 (Exp#4, #5)

**Category:** 도메인 누락 / Critical
**Effort:** M (4-5h)
**Dependencies:** None

**Files:**
- Modify: `db/seeds/checklist_items_summary.json` — bump rights-021 priority "중"→"상", add 5 items
- Modify: `app/models/checklist_item.rb` (or wherever `opportunity_type` enum lives) — add `preferred_purchase_risk`
- Modify: `app/components/registry_timeline_component.html.erb` — visualize `preferred_purchase_risk` rights
- Test: `test/models/checklist_item_test.rb` (or fixture-driven test)

**5 new items to add (E-4):**

| code | category | priority | question |
|---|---|---|---|
| `rights-022` | 권리분석 | 상 | 공유지분 매각인지 확인했습니까? (지분 비율 기재) |
| `rights-023` | 권리분석 | 상 | 공유자우선매수권 행사 여부를 확인했습니까? |
| `rights-024` | 권리분석 | 상 | 임의경매 vs 강제경매 구분이 명세서에 기재되어 있습니까? |
| `rights-025` | 권리분석 | 중 | 토지별도등기 여부를 확인했습니까? |
| `rights-026` | 권리분석 | 중 | NPL(부실채권) 매수 가능성이 있는 물건입니까? |

- [ ] **Step 1: Write failing test**

```ruby
# test/models/checklist_item_test.rb
test "rights-021 (전세사기 특별법 우선매수권) is priority 상" do
  item = ChecklistItem.find_by(code: "rights-021")
  assert_equal "상", item.priority
end

test "veteran-required items rights-022..026 exist" do
  %w[rights-022 rights-023 rights-024 rights-025 rights-026].each do |code|
    assert ChecklistItem.exists?(code: code), "#{code} must exist in seeds"
  end
end
```

- [ ] **Step 2: Run → FAIL**

- [ ] **Step 3: Edit `db/seeds/checklist_items_summary.json`**

Locate `"code": "rights-021"`, change `"priority": "중"` → `"priority": "상"`. Append 5 new entries with full description/question/yes_action/no_action fields (mirror existing pattern).

- [ ] **Step 4: Reseed**

```bash
bin/rails db:seed
bin/rails test test/models/checklist_item_test.rb
```

Expected: PASS.

- [ ] **Step 5: Add `preferred_purchase_risk` opportunity_type**

```ruby
# app/models/inspection_result.rb (or wherever enum lives)
opportunity_type: { hug_waiver: 0, npl_buy: 1, preferred_purchase_risk: 2, ... }
```

Plus a `db/migrate/<ts>_add_preferred_purchase_risk_to_opportunity_types.rb` if stored as integer enum, OR seed-only update if stored as string.

- [ ] **Step 6: Commit**

```bash
git add db/seeds/checklist_items_summary.json \
        app/models/checklist_item.rb app/models/inspection_result.rb \
        db/migrate/*_preferred_purchase_risk*.rb \
        test/models/checklist_item_test.rb
git commit -m "feat(checklist): bump rights-021 to priority 상 + add 5 veteran items

공유자우선매수권 행사 시 낙찰 무산 위험. priority '중' → '상'.
공유지분, 임의경매 구분, 토지별도등기, NPL 등 베테랑 필수 5개 항목 추가 (Exp#4, #5).
opportunity_type에 preferred_purchase_risk enum 추가."
```

---

### Task A7: incomplete-safe 가드 — priority="상" 미입력 시 :safe 차단 (Exp#13, #14)

**Category:** 데이터 누락 안전망 / Critical
**Effort:** M (3-4h)
**Dependencies:** A6 (new priority="상" items affect the gate)

**Files:**
- Modify: `app/services/inspection/inspection_rating_service.rb` lines 22-35
- Modify: `app/views/inspections/grades/show.html.erb` lines 8-23 — show banner when gated
- Test: `test/services/inspection/inspection_rating_service_test.rb`

- [ ] **Step 1: Write failing test**

```ruby
test "1 answered + 80 unanswered priority='상' items → :incomplete (NEVER :safe)" do
  property = properties(:case_2026_1234)
  inspection = inspections(:in_progress)
  # only one priority='상' item answered
  InspectionResult.create!(inspection: inspection, checklist_item_code: "rights-001", has_risk: false)

  service = Inspection::InspectionRatingService.new(inspection)
  assert_equal :incomplete, service.overall_rating
end

test "all priority='상' answered with no risk → :safe" do
  inspection = inspections(:complete_safe)
  service = Inspection::InspectionRatingService.new(inspection)
  assert_equal :safe, service.overall_rating
end
```

- [ ] **Step 2: Run → FAIL**

- [ ] **Step 3: Implement coverage gate**

```ruby
# app/services/inspection/inspection_rating_service.rb
def overall_rating
  return :incomplete if priority_high_coverage < REQUIRED_COVERAGE

  risk_results = answered_results.select(&:has_risk?)
  return :safe if risk_results.empty?
  ...
end

REQUIRED_COVERAGE = 1.0  # 100% of priority='상' items must be answered

private

def priority_high_coverage
  high_codes = ChecklistItem.where(priority: "상").pluck(:code)
  return 0.0 if high_codes.empty?
  answered = inspection.inspection_results.where(checklist_item_code: high_codes).where.not(has_risk: nil).count
  answered.to_f / high_codes.size
end
```

- [ ] **Step 4: Run → PASS**

- [ ] **Step 5: Add banner to grade page**

```erb
<%# app/views/inspections/grades/show.html.erb %>
<% if @grade.overall_rating == :incomplete %>
  <div class="rounded border-l-4 border-red-500 bg-red-50 p-4 mb-6">
    <h3 class="font-semibold text-red-900">⚠️ 입력 부족 — 입찰 검토 보류</h3>
    <p class="text-sm mt-1">
      필수 권리분석 항목(<%= @grade.unanswered_high_priority_count %>건) 미입력 상태입니다.
      안전 판정을 받기 전에 모든 priority="상" 항목을 답변해 주세요.
    </p>
  </div>
<% end %>
```

- [ ] **Step 6: Commit**

```bash
git add app/services/inspection/inspection_rating_service.rb \
        app/views/inspections/grades/show.html.erb \
        test/services/inspection/inspection_rating_service_test.rb
git commit -m "fix(inspection): block :safe rating when priority='상' coverage < 100%

기존: 1개만 답해도 risk 없으면 :safe → 가장 위험한 거짓 안심.
수정: priority='상' 100% 커버리지 미달 시 :incomplete 강제 유지.
(Exp#13, #14)"
```

---

### Task A8: bid_opinion 권유성 문구 → 위험 카운트 표기로 변경 (Exp#38)

**Category:** 법적 책임 / Critical
**Effort:** S (1-2h)
**Dependencies:** None

**Files:**
- Modify: `app/components/bid_opinion_component.rb` lines 18-22 — replace advisory phrasing
- Modify: `app/components/bid_opinion_component.html.erb` — update render
- Test: `test/components/bid_opinion_component_test.rb`

- [ ] **Step 1: Write failing test**

```ruby
require "test_helper"
class BidOpinionComponentTest < ViewComponent::TestCase
  test "never renders 입찰 권유 phrasing" do
    component = BidOpinionComponent.new(risk_count: 0, opportunity_count: 5)
    rendered = render_inline(component).to_s
    refute_match(/입찰을 권/, rendered)
    refute_match(/입찰 검토 가능/, rendered)
  end

  test "shows risk count and 'self-judgment required'" do
    component = BidOpinionComponent.new(risk_count: 3, opportunity_count: 1)
    rendered = render_inline(component).to_s
    assert_match(/위험 항목 3건/, rendered)
    assert_match(/본인 판단 필요/, rendered)
  end
end
```

- [ ] **Step 2: Run → FAIL; Step 3: rewrite**

```ruby
# app/components/bid_opinion_component.rb
class BidOpinionComponent < ViewComponent::Base
  def initialize(risk_count:, opportunity_count:)
    @risk_count = risk_count
    @opportunity_count = opportunity_count
  end

  def headline
    "위험 항목 #{@risk_count}건 · 기회 항목 #{@opportunity_count}건"
  end

  def disclaimer
    "본 도구는 권리분석 보조이며 입찰 권유가 아닙니다. 모든 투자 결정의 책임은 사용자에게 있습니다."
  end
end
```

```erb
<%# app/components/bid_opinion_component.html.erb %>
<div class="rounded border bg-zinc-50 p-4">
  <h3 class="font-semibold"><%= headline %></h3>
  <p class="mt-1 text-sm">본인 판단 필요. 베테랑/공인중개사 상담을 권장합니다.</p>
  <p class="mt-2 text-xs text-zinc-600"><%= disclaimer %></p>
</div>
```

- [ ] **Step 4: Run → PASS; Step 5: Commit**

```bash
git add app/components/bid_opinion_component.{rb,html.erb} \
        test/components/bid_opinion_component_test.rb
git commit -m "fix(bid): replace advisory phrasing with risk count + disclaimer

'입찰 권하지 않습니다' / '입찰 검토 가능합니다' → 변호사법/중개사법 자문
경계 위험. 단순 위험 카운트만 표기, 권유성 문구 제거 (Exp#38)."
```

---

### Task A9: 비로그인 랜딩 페이지 신설 (Beg#1, Beg-Top1, related Beg#32)

**Category:** 맥락 부재 / Critical (Beginner Top-1 출시 차단)
**Effort:** M (4-6h)
**Dependencies:** A1 (links to terms/privacy in footer of landing)

**Files:**
- Modify: `app/controllers/home_controller.rb` lines 5-9 — split unauth path → render landing
- Create: `app/views/home/landing.html.erb`
- Create: `app/components/home/landing_component.{rb,html.erb}`
- Modify: `config/routes.rb` if needed (root unaffected)
- Test: `test/system/landing_test.rb`

- [ ] **Step 1: Write failing test**

```ruby
require "application_system_test_case"
class LandingTest < ApplicationSystemTestCase
  test "unauthenticated visitor sees landing instead of being bounced to onboarding" do
    visit root_path
    assert_text "법원 경매 권리분석 도구"  # tagline
    assert_link "체험 시작하기"
    assert_link "로그인"
    refute_current_path %r{/onboardings}
  end

  test "logged-in user with completed onboarding goes to /properties" do
    sign_in_as(users(:onboarded))
    visit root_path
    assert_current_path "/properties"
  end
end
```

- [ ] **Step 2: Run → FAIL; Step 3: refactor controller**

```ruby
# app/controllers/home_controller.rb
class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    if current_user
      redirect_to current_user.onboarded? ? properties_path : new_onboarding_path
    else
      render :landing, layout: "marketing"  # or "application"
    end
  end
end
```

- [ ] **Step 4: Build landing component**

```erb
<%# app/views/home/landing.html.erb %>
<%= render Home::LandingComponent.new(
  tagline: "법원 경매 권리분석 도구",
  subtitle: "낙찰 전 89개 체크리스트와 AI 분석으로 위험을 미리 짚어 봅니다.",
  primary_cta: { label: "체험 시작하기", href: new_session_path },
  secondary_cta: { label: "로그인", href: new_session_path }
) %>
```

```ruby
# app/components/home/landing_component.rb
module Home
  class LandingComponent < ViewComponent::Base
    def initialize(tagline:, subtitle:, primary_cta:, secondary_cta:)
      @tagline = tagline
      @subtitle = subtitle
      @primary_cta = primary_cta
      @secondary_cta = secondary_cta
    end
  end
end
```

```erb
<%# app/components/home/landing_component.html.erb %>
<section class="bg-gradient-to-b from-blue-50 to-white py-16">
  <div class="mx-auto max-w-4xl px-4 text-center">
    <h1 class="text-4xl font-bold tracking-tight"><%= @tagline %></h1>
    <p class="mt-4 text-lg text-zinc-700"><%= @subtitle %></p>
    <div class="mt-8 flex justify-center gap-3">
      <%= link_to @primary_cta[:label], @primary_cta[:href], class: "btn-primary px-6 py-3" %>
      <%= link_to @secondary_cta[:label], @secondary_cta[:href], class: "btn-secondary px-6 py-3" %>
    </div>
  </div>
  <div class="mx-auto mt-16 max-w-5xl grid grid-cols-1 gap-6 px-4 sm:grid-cols-3">
    <div><h3 class="font-semibold">89개 체크리스트</h3><p class="text-sm text-zinc-600">권리/명도/세무 누락 항목 자동 감지</p></div>
    <div><h3 class="font-semibold">AI 권리분석</h3><p class="text-sm text-zinc-600">PDF 업로드 → 등기부 타임라인 시각화</p></div>
    <div><h3 class="font-semibold">명도 시뮬레이터</h3><p class="text-sm text-zinc-600">점유자 유형별 단계·비용·기간 추정</p></div>
  </div>
</section>
```

- [ ] **Step 5: Run → PASS; Step 6: Commit**

```bash
git add app/controllers/home_controller.rb \
        app/views/home/landing.html.erb \
        app/components/home/landing_component.{rb,html.erb} \
        test/system/landing_test.rb
git commit -m "feat(landing): add unauthenticated landing page at root

비로그인 시 곧바로 onboarding으로 튕기던 동작 제거. 서비스 정체와
가치를 한 화면에 보여주고 체험 시작/로그인 CTA 두 개 노출 (Beg#1)."
```

---

### Task A10: 온보딩 step1 — '유용자금'/'LTV' 등 회계 용어 평이화 (Beg#2, #4)

**Category:** 용어 장벽 / Critical
**Effort:** S (2h)
**Dependencies:** None (pure copy + small UI)

**Files:**
- Modify: `app/views/onboardings/step1.html.erb` lines 4-7, 11-13, 29-39
- Modify: `app/views/onboardings/step3.html.erb` lines 21, 46 — LTV 풀이 + tooltip
- Modify: `app/components/onboarding/help_tooltip_component.{rb,html.erb}` — 새 컴포넌트 또는 기존 재사용
- Test: `test/system/onboarding_terms_test.rb`

- [ ] **Step 1: Failing test**

```ruby
test "step1 uses plain term '지금 쓸 수 있는 현금' not '유용자금'" do
  sign_in_as(users(:fresh))
  visit new_onboarding_path
  assert_text "지금 쓸 수 있는 현금"
  assert_text "예: 예금·CMA"
end

test "step3 LTV term has explainer" do
  sign_in_as(users(:onboarding_step3))
  visit onboarding_step3_path
  assert_text "대출 비율"
  assert_selector "[data-tooltip-target='content']", text: /집값 대비 빌릴 수 있는 비율/
end
```

- [ ] **Step 2-5: edit copy + tooltip; commit**

```bash
git commit -m "fix(onboarding): plain Korean for 유용자금/LTV (Beg#2, #4)"
```

---

### Task A11: eviction_guide 단계/분기 stub 페이지 콘텐츠 채우기 (Beg#21, Beg-Top3)

**Category:** 빈 상태 / Critical
**Effort:** M (4-5h)
**Dependencies:** None

**Files:**
- Modify: `app/views/eviction_guide/steps/show.html.erb` (현재 한 줄 stub)
- Modify: `app/views/eviction_guide/branches/show.html.erb`
- Create: `app/views/eviction_guide/steps/_detail.html.erb` (shared partial)
- (Reuse) `app/components/eviction_guide/step_card_component.*`
- Test: `test/system/eviction_step_detail_test.rb`

- [ ] **Step 1: Failing system test**

```ruby
test "clicking a step in simulator result opens detail with description, docs, duration" do
  sign_in_as(users(:onboarded))
  property = properties(:case_2026_1234)
  visit eviction_guide_simulator_path(property_id: property.id)
  click_on "직접 입력으로 시뮬레이션"
  click_on "후순위 임차인"
  click_on "결과 보기"  # may need to answer Qs first
  click_on "1단계 — 인도명령 신청"

  assert_text "필요 서류"
  assert_text "예상 기간"
  refute_text "1단계 — 인도명령 신청\n"  # not just a one-line stub
end
```

- [ ] **Step 2: Build partial**

```erb
<%# app/views/eviction_guide/steps/_detail.html.erb %>
<article class="prose mx-auto max-w-3xl py-6">
  <h1><%= @step.name %></h1>
  <p class="lead"><%= @step.description %></p>
  <% if @step.required_documents.any? %>
    <h2>필요 서류</h2>
    <ul>
      <% @step.required_documents.each { |d| %><li><%= d %></li><% } %>
    </ul>
  <% end %>
  <h2>예상 기간</h2>
  <p><%= @step.estimated_duration %></p>
  <h2>예상 비용</h2>
  <p><%= number_to_currency(@step.estimated_cost, unit: "원") %></p>
  <% if @step.tips.present? %>
    <h2>실무 팁</h2>
    <%= simple_format(@step.tips) %>
  <% end %>
</article>
```

`show.html.erb` becomes: `<%= render "detail" %>`. Same for branches.

- [ ] **Step 3-5: run, pass, commit**

```bash
git commit -m "feat(eviction): replace stub step/branch pages with full detail (Beg#21)"
```

---

### Task A12: 체크리스트 — 인라인 용어 설명 + 초심자 모드 토글 (Beg#5, #6, Beg-Top4)

**Category:** 인지 부하 / Critical
**Effort:** L (6-8h)
**Dependencies:** None

**Files:**
- Create: `app/components/inspection/term_glossary_component.{rb,html.erb}`
- Create: `app/javascript/controllers/glossary_controller.js` (Stimulus, click-toggle for mobile)
- Modify: `app/components/inspection_item_component.html.erb` — wrap question text with glossary spans
- Modify: `app/components/inspection_tabs_component.html.erb` (or layout) — add 초심자 모드 toggle
- Modify: `db/seeds/checklist_items_summary.json` — add `glossary_terms: ["대항력", "말소기준권리", ...]` per item
- Modify: User model: `column :beginner_mode, default: false`
- Test: `test/system/checklist_glossary_test.rb`

**Glossary source:** Build a small `db/seeds/glossary.json` with 20-30 core terms (대항력, 말소기준권리, 명도, 배당, 유치권, HUG, 가등기, 가처분, 법정지상권, 임차인, 우선변제, 최우선변제, 확정일자, 인도명령, 명도소송, 공유자우선매수권, 매각물건명세서, 등기부등본, 사건번호, 채권최고액, ...).

- [ ] **Step 1: Failing test**

```ruby
test "glossary tooltip shows on click for any term in checklist question" do
  sign_in_as(users(:onboarded))
  property = properties(:case_2026_1234)
  visit edit_property_inspection_path(property)
  find("[data-glossary-term='대항력']").click
  assert_text "전입신고 익일 0시부터 발생하는 임차인 권리"
end

test "beginner_mode toggle persists user preference" do
  user = users(:onboarded)
  sign_in_as(user)
  visit edit_property_inspection_path(properties(:case_2026_1234))
  find("[data-action='click->beginner-mode#toggle']").click
  assert user.reload.beginner_mode?
end
```

- [ ] **Step 2: Migration + seed + component**

```ruby
# db/migrate/<ts>_add_beginner_mode_to_users.rb
class AddBeginnerModeToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :beginner_mode, :boolean, default: true, null: false
  end
end
```

`app/components/inspection/term_glossary_component.rb`:

```ruby
module Inspection
  class TermGlossaryComponent < ViewComponent::Base
    GLOSSARY = JSON.parse(Rails.root.join("db/seeds/glossary.json").read).freeze

    def initialize(text:)
      @text = text
    end

    def annotated
      escaped = ERB::Util.h(@text)
      GLOSSARY.each do |term, definition|
        escaped = escaped.gsub(term) { |t| <<~HTML.strip_heredoc.html_safe
          <span class="glossary-term cursor-help underline decoration-dotted text-blue-700"
                data-controller="glossary"
                data-glossary-term="#{term}"
                data-action="click->glossary#show"
                data-glossary-definition-value="#{ERB::Util.h(definition)}">#{t}</span>
        HTML
        }
      end
      escaped.html_safe
    end
  end
end
```

(See repo CLAUDE.md / `docs/standards/STACK.md` for component conventions; align styles with existing.)

- [ ] **Step 3-6: write Stimulus controller, wire into `inspection_item_component`, add toggle, run all tests, commit**

```bash
git commit -m "feat(inspection): inline term glossary + beginner_mode toggle

89개 체크리스트 항목의 핵심 용어(대항력/말소기준권리/명도/배당 등)에
점선 밑줄을 넣고 클릭/호버로 정의 노출. 사용자별 beginner_mode 플래그로
on/off (Beg#5, #6, Beg-Top4)."
```

---

### Task A13: 외부 LLM 전송 데이터 명시 + AI 자동분석 탭 비활성 처리 (Beg#10, #28)

**Category:** 불안 / Critical (출시 차단 — 신뢰)
**Effort:** S-M (3h)
**Dependencies:** None

**Files:**
- Create: `app/components/llm_data_disclosure_component.{rb,html.erb}`
- Modify: `app/views/analyses/new.html.erb` — render disclosure panel; disable/hide auto tab
- Modify: `app/views/analyses/_form.html.erb` — same
- Test: `test/system/llm_data_disclosure_test.rb`

- [ ] **Step 1: Failing test**

```ruby
test "AI 자동분석 tab is hidden when feature_flag(:llm_auto_disabled) is on" do
  Rails.application.config.feature_flags = { llm_auto_disabled: true }
  sign_in_as(users(:onboarded))
  visit new_analysis_path
  refute_selector "[data-tab='auto']"
end

test "data-disclosure panel lists what is sent and retention policy" do
  sign_in_as(users(:onboarded))
  visit new_analysis_path
  assert_text "전송 항목: PDF 텍스트만"
  assert_text "1회 분석 후 즉시 폐기"
  assert_text "주소·주민번호 자동 마스킹"
end
```

- [ ] **Step 2-5: build component, hide auto tab via flag, commit**

```bash
git commit -m "feat(analyses): disable auto tab + show LLM data disclosure (Beg#10, #28)"
```

---

## Phase A Acceptance Checklist (must be all green by 2026-05-18 EOD)

- [ ] A1 약관/방침 정식 콘텐츠 + 링크 동작
- [ ] A2 case_number 미입력/충돌 시 명시적 에러
- [ ] A3 dividend_requested prompt/code 정합 + null 표시 "확인 필요"
- [ ] A4 unevaluated_rights[] 분리 + 보고서 disclaimer
- [ ] A5 동일자 전입 경고 표시
- [ ] A6 rights-021 priority "상" + 5개 새 항목 + 시드 + opportunity_type enum
- [ ] A7 priority="상" 100% 미달 시 :safe 차단 + 배너
- [ ] A8 bid_opinion 권유성 문구 제거 + disclaimer
- [ ] A9 비로그인 랜딩 페이지
- [ ] A10 온보딩 용어 평이화 (유용자금, LTV)
- [ ] A11 명도 step/branch 상세 페이지 채우기
- [ ] A12 체크리스트 인라인 용어 설명 + 초심자 모드
- [ ] A13 LLM 전송 데이터 명시 + auto 탭 비활성

---

# PHASE B — Post-launch Wave 1 (2026-05-20 → 2026-06-19, ≈4 weeks)

**Pace:** ~7-8 PR/week. 30 tasks across 4 weeks. Each task TDD, commit per task.

**Compact format** below: each entry has Files / Test approach / Effort / Code skeleton (key snippet only).

### Week 1 — LLM 신뢰도 + 권리분석 정확성 (8건)

| ID | Audit Ref | Task | Files | Test | Effort |
|---|---|---|---|---|---|
| B1 | E-3 | 배당표 시뮬레이터 (단순화) | `app/services/inspection/distribution_simulator.rb` (new), `rights_analysis_report_component` | service test: 매각가 입력 → 우선변제 후 미배당 잔액 | L (10h) |
| B2 | E-6 | 당해세 vs 일반국세 분리 항목 | `db/seeds/checklist_items_summary.json` (rights-008 split) | model test: 두 항목 모두 존재 | S (2h) |
| B3 | E-9 | confidence=medium은 verdict 1단계 강등 | `app/services/inspection/inspection_result_mapper.rb` | service test | S (2h) |
| B4 | E-10 | LLM self-consistency 검출 prompt 추가 | `app/services/llm/pdf_prompt_builder.rb` | prompt test (string match) | M (4h) |
| B5 | E-11 | extraction_failed 시 failure_reason + 재시도 UI | `pdf_analysis_service.rb`, `analyses/show.html.erb` | system test | M (4h) |
| B6 | E-12 | 채권액 amount_type 필드 추가 | `pdf_prompt_builder.rb`, view 표시 | prompt + view test | S (2h) |
| B7 | E-19 | source_doc/page_number/quote 강제 + UI 인용 | prompt + `evidence_link_component` (new) | prompt + component test | M (5h) |
| B8 | E-41 | hug_waiver 명시적 확약서 인용 강제 | prompt + view | prompt test | S (2h) |

**Code snippet (B3 — confidence demote):**

```ruby
# inspection_result_mapper.rb
verdict = case llm_result["confidence"]
when "high" then llm_result["verdict"]
when "medium" then demote(llm_result["verdict"])  # safe→caution, caution→danger
else nil  # require manual confirmation
end
```

### Week 2 — 워크플로우 효율 (전문가) (7건)

| ID | Audit Ref | Task | Files | Test | Effort |
|---|---|---|---|---|---|
| B9 | E-20 | 다물건 비교 보드 | `app/views/properties/compare.html.erb`, controller action | system test: 3건 선택 → 테이블 | L (10h) |
| B10 | E-21 | UserProperty 메모/사진/임장노트 | migration, `user_properties_controller`, view | model + system | L (8h) |
| B11 | E-23 | bulk import (CSV/줄바꿈 paste) | `properties/bulk_import_controller`, service | service test | M (5h) |
| B12 | E-28, E-34, E-35 | 매각기일 카드 표시 + D-day | `property_card_component`, `auction_schedule` 사용처 | component + system | M (5h) |
| B13 | E-30 | CSV/Excel export | `app/services/export/inspection_csv_exporter.rb` (new) | service test | M (4h) |
| B14 | E-43 | 매물 상세 → PDF 업로드 통합 | `properties/show.html.erb` | system test | S (3h) |
| B15 | E-44 | LLM 분석 로그 UI 노출 | `analyses/history.html.erb` (new) | system test | S (3h) |

### Week 3 — 초심자 친화도 (10건)

| ID | Audit Ref | Task | Files | Test | Effort |
|---|---|---|---|---|---|
| B16 | B-3 | 부대비용 항목 툴팁 (취득세, 법무사비 등) | `onboardings/step2.html.erb` | system test | S (2h) |
| B17 | B-7 | "Yes/No" 영문 → 한국어 | `inspection_item_component.html.erb:53,59` | component test | XS (30m) |
| B18 | B-8 | 사건번호 입력 옆 출처 안내 | `properties/_case_number_form` | system test | S (1h) |
| B19 | B-9 | 빈 상태에 "물건 검색" CTA | `properties/index.html.erb:74-82` | system test | S (1h) |
| B20 | B-11 | AI 수동분석 4단계 스텝퍼 + 스크린샷 | `analyses/_manual_form.html.erb` | system test | M (4h) |
| B21 | B-13, B-14 | 한국어 model validation 메시지 + 에러 가이드 | `config/locales/ko.yml`, `error.html.erb` | system test | S (2h) |
| B22 | B-15 | 명도 시뮬 빈 상태 시 직접입력 탭 기본 | `eviction_guide/simulator.html.erb` | system test | S (1h) |
| B23 | B-17 | "분기 경로 진입" 평이한 표현 | `simulator_question_component.html.erb:9` | component test | XS (15m) |
| B24 | B-18 | 등급 페이지 8섹션 → "초심자 1·2·3 순서" 가이드 | `inspections/grades/show.html.erb:8-23` | system test | M (3h) |
| B25 | B-19 | 필요경비/경비불산입 툴팁 | `profit_calculator_component.html.erb:184` | component test | S (1h) |

### Week 4 — 안전망 + 면책 + 모바일 (5건)

| ID | Audit Ref | Task | Files | Test | Effort |
|---|---|---|---|---|---|
| B26 | E-16, E-18 | AI 결과 history + 사용자 확인 후 자동 덮어쓰기 차단 | migration `inspection_result_versions`, mapper | service test | L (8h) |
| B27 | E-17 | 임차인 inline edit | `tenants_controller` (new), turbo frames | system test | M (5h) |
| B28 | E-37 | 모든 추정/예측 결과에 disclaimer 분산 배치 | `legal_disclaimer_component` 위치 확장 | component test | S (2h) |
| B29 | B-22, B-37 | 삭제 버튼 더보기 메뉴로 + confirm 평이화 | `property_card_component` | system test | M (3h) |
| B30 | B-23, E-42 | 모바일 인스펙션 탭 드롭다운 + max_tokens 16384 상향 | `inspection_tabs_component`, `llm/anthropic.rb` | system + adapter test | M (5h) |

**Phase B exit criteria:** All 30 tasks merged. Beginner Top-5 + Expert "출시 후 추가" Top-5 covered.

---

# PHASE C — Post-launch Wave 2 (2026-06-20 → 2026-08-31, ≈10 weeks)

Tabular roadmap. Schedule expansion to full TDD task structure when each item is sprint-planned.

### C-1: Medium 인지 부하 / 모바일 / 빈 상태 (~22건)

| ID | Audit | Cat | Files | Effort | Dep |
|---|---|---|---|---|---|
| C1 | B-23 | 모바일 | `inspection_tabs_component.html.erb:1` (overflow-x → 드롭다운 sm 이하) | M | B30 일부 |
| C2 | B-24 | 모바일 | `onboardings/step1.html.erb:29-39` 세로 스택 | XS | — |
| C3 | B-25 | 모바일 | `simulator_question_component.html.erb:46-74` 위/아래 스택 | XS | — |
| C4 | B-26 | 맥락 | "F02" 등 내부 코드 노출 제거 (`f02_prefill_component`) | XS | — |
| C5 | B-27 | 맥락 | `simulator_question_component:31-34` Q코드 숨김 | XS | — |
| C6 | B-30 | 인지 | `onboardings/complete.html.erb:35` 진입 화면 변경 | S | A11 |
| C7 | B-31 | 모바일 | 헤더 예산 뱃지 모바일 햄버거 이동 | S | — |
| C8 | B-32 | 맥락 | 매뉴얼 헤로 직후 "지금 시작하기" CTA | S | A9 |
| C9 | B-33 | 인지 | 사이드바 라벨 정리 (물건 목록/내 물건) | S | — |
| C10 | B-34 | 인지 | 분석 전/후 카드 버튼 분기 (`properties/show.html.erb:30-44`) | S | — |
| C11 | B-35 | 빈 상태 | 물건 상세 진행 표시기 | M | — |
| C12 | B-36 | 모바일 | 카드 "?" 호버 → 클릭 토글 | S | — |
| C13 | B-38 | 모바일 | 시뮬 결과 카드 grid sm:1 | XS | — |
| C14 | B-39 | 불안 | 등급 페이지 PDF 옆 "전문가 상담" CTA | S | — |
| C15 | B-40 | 인지 | step3 산식 공개 토글 | S | — |
| C16 | B-41 | 빈 상태 | 헤더 "❓도움말" 상시 노출 + FAQ | M | — |
| C17 | B-42 | 모바일 | 인스펙션 sticky header 2단 분리 | M | — |
| C18 | B-43 | 인지 | 온보딩 step2 점진적 공개 | M | — |
| C19 | B-44 | 맥락 | 시뮬레이터 "약 N개 질문 / 3분" 안내 | XS | — |
| C20 | B-45 | 에러 | 코드(F02-Q3) 표기 제거 | XS | C4 |

(20개 + B-20 카드 디테일 → 21~22 정도 매핑.)

### C-2: 전문가 고급 기능 / Edge cases (~14건)

| ID | Audit | Cat | Files | Effort | Dep |
|---|---|---|---|---|---|
| C21 | E-22 | 단축키 | Stimulus keymap (J/K/Y/N/S) | M | — |
| C22 | E-24 | 입찰가 | 회차별 저감률 + 인근 낙찰가 통계 시드 | L | court auction data |
| C23 | E-25 | 양도세 | 조정대상지역 입력 + 매트릭스 세분화 | L | — |
| C24 | E-26 | 취득세 | 면적/지역/가액 매트릭스 | M | C23 |
| C25 | E-27 | 배당 | 소액임차인 최우선변제 자동 계산 (시행령 별표 시드) | L | B1 |
| C26 | E-29 | DSR | 연봉/부채 입력 → DSR 한도 계산 | M | — |
| C27 | E-31 | 에지 | 오피스텔/상가/토지/공장 property_type 분기 | L | — |
| C28 | E-32 | 에지 | 공유지분 매물 플래그 + 보증금 비율 적용 | M | A6 |
| C29 | E-33 | 타이밍 | 인도명령 6개월 D-day 추적 | M | B12 |
| C30 | E-34 | 알림 | Notification 채널 (이메일 + in-app) | L | B12 |
| C31 | E-39 | 보안 | analyses#prompt endpoint 노출 축소 | XS | — |
| C32 | E-40 | 이동성 | JSON export + 표준 schema 문서화 | M | B13 |

### C-3: Low (남은 항목, ~5건)

| ID | Audit | Cat | Effort |
|---|---|---|---|
| C33 | B-45 | 에러 — 코드 표기 (이미 C20에 포함) | — |
| C34 | residual mobile / a11y | 접근성 점검 (aria-labels, focus traps) | M |

(Phase C 총 ~30-35 tasks. 정확한 갯수는 dedupe 후 정해짐.)

**Phase C exit criteria:** 모든 Medium/Low 처리되거나 명시적 "WONTFIX (재평가 후)"로 백로그 정리.

---

## Cross-cutting Standards

- **Korean** for user-facing text and UI strings; **English** for code, tests, commit messages, this plan.
- **TDD red-green-refactor** for every task. Test file path is mandatory in each task's "Files" block.
- **Tidy First**: structural commits (extract component, migration-only) separate from behavior commits.
- **Per-task commit** — never batch.
- **Component conventions:** ViewComponent under `app/components/<feature>/`, Stimulus under `app/javascript/controllers/`, system tests under `test/system/`.
- **i18n:** all new strings via `t(".key")` referencing `config/locales/ko.yml` (NOT inline Korean) where the file already does so. New views may inline Korean if surrounding views also inline.
- **Disclaimer placement:** `app/components/legal_disclaimer_component` reused (B28); avoid duplicating the copy.

---

## Self-Review Notes

**Spec coverage:**
- Beginner 45 issues → mapped: A9 (#1), A10 (#2,4), B16 (#3), A12 (#5,6), B17 (#7), B18 (#8), B19 (#9), A13 (#10,28), B20 (#11), already-handled-A2 (#12), B21 (#13,14), B22 (#15), A12 partial overlap (#16), B23 (#17), B24 (#18), B25 (#19), A11 carries (#20→A4 disclosure overlap; full beginner #20 fix is C in result-page formatting, deferred), A11 (#21), B29 (#22), B30 (#23), C2 (#24), C3 (#25), C4 (#26), C5 (#27), already A13 (#28), A1 (#29), C6 (#30), C7 (#31), C8 (#32), C9 (#33), C10 (#34), C11 (#35), C12 (#36), B29 (#37), C13 (#38), C14 (#39), C15 (#40), C16 (#41), C17 (#42), C18 (#43), C19 (#44), C20 (#45). ✅ all 45 mapped.
- Expert 44 issues → mapped: A5 (#1), A4 (#2), B1 (#3), A6 (#4,5), B2 (#6), A2 (#7), A3 (#8), B3 (#9), B4 (#10), B5 (#11), B6 (#12), A7 (#13,14), A2 (#15), B26 (#16), B27 (#17), B26 (#18), B7 (#19), B9 (#20), B10 (#21), C21 (#22), B11 (#23), C22 (#24), C23 (#25), C24 (#26), C25 (#27), B12 (#28), C26 (#29), B13 (#30), C27 (#31), C28 (#32), C29 (#33), C30 (#34), B12 (#35), A1 (#36), B28 (#37), A8 (#38), C31 (#39), C32 (#40), B8 (#41), B30 (#42), B14 (#43), B15 (#44). ✅ all 44 mapped.

**Placeholder scan:** No "TBD/TODO/fill in details" outside Phase C tabular form. Phase C entries intentionally show category + file + effort (the user-requested fields) and will be expanded to full TDD task structure when sprint-planned — this is roadmap scope, not implementation hand-off scope. Acceptable per the user's "단계별 로드맵" request.

**Type consistency:**
- `unevaluated_rights[]` (A4) — used consistently in service + component.
- `same_day_warning` / `warning_message` (A5) — same keys in service + view.
- `priority_high_coverage` / `REQUIRED_COVERAGE` (A7) — consistent.
- `CaseNumberMissingError` / `CaseNumberMismatchError` (A2) — both raised + tested.
- `beginner_mode` boolean (A12) — column + test.
- No conflicting names found.

**Gaps surfaced during review:** Phase C #C24 (취득세) depends on C23 (양도세) for shared 조정대상지역 input — recorded in Dep column. Phase C #C30 alerts depend on B12 (auction_schedule UI) — recorded.

---

## Plan complete

Saved to `docs/superpowers/plans/2026-05-09-ux-audit-fixes-plan.md`.
