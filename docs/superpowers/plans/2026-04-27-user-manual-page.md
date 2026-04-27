# User Manual Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 사용자매뉴얼 페이지 1개를 추가해 신규/기존 사용자 모두에게 전체 워크플로와 자신의 현재 위치를 보여준다. 사이드바 "시작하기" 그룹 신설, 낙찰 전(4) / 낙찰 후(2) 2단 골격, "이어서 하기" 진행 상태 표시.

**Architecture:** Rails 8 + ViewComponent + Tailwind. 도메인은 `Manuals::Progress` PORO가 6스텝 상태를 산출, 뷰는 `ProgressResult` DTO를 받아 6개 ViewComponent로 조립. 아코디언은 네이티브 `<details>` 사용 (JS 0줄). 새 모델/마이그레이션 없음 — 기존 테이블만 조회.

**Tech Stack:** Rails 8.1, ViewComponent, Tailwind CSS, Heroicon, Minitest, Capybara (system tests), ko-only i18n.

**Spec:** [docs/superpowers/specs/2026-04-27-user-manual-page-design.md](../specs/2026-04-27-user-manual-page-design.md)

**Conventions:**
- Korean for UI copy and conversation, English for code/commits
- TDD Red-Green-Refactor — failing test first, every task
- Tidy First — structural commits separate from behavioral commits
- Commit at every green or refactor

---

## File Structure

**New files:**
- `app/controllers/manuals_controller.rb` — show 액션
- `app/models/manuals/step.rb` — Data class (number, key, status, detail)
- `app/models/manuals/progress_result.rb` — Data class (steps, current_step, continue_cta)
- `app/models/manuals/progress.rb` — PORO, 6개 스텝 상태 산출
- `app/components/manual/component.rb` + `.html.erb` — 페이지 조립
- `app/components/manual/hero/component.rb` + `.html.erb` — 헤드라인 + 이어서 하기 카드
- `app/components/manual/flow_strip/component.rb` + `.html.erb` — 6박스 가로 스트립
- `app/components/manual/phase_section/component.rb` + `.html.erb` — 낙찰 전/후 섹션
- `app/components/manual/step_card/component.rb` + `.html.erb` — 아코디언 카드
- `app/views/manuals/show.html.erb` — render Manual::Component
- `config/locales/manuals.ko.yml` — 모든 카피
- `app/assets/images/manual/{01-budget,02-properties,03-ai-analysis,04-checklist,05-eviction-guide,06-simulator}.png` — placeholder (마지막 task에서 추가)

**Modified files:**
- `config/routes.rb` — add `resource :manual, only: [:show]`
- `app/components/sidebar/component.rb` — add `시작하기` 그룹 (최상단)

**Test files (mirror src):**
- `test/controllers/manuals_controller_test.rb`
- `test/models/manuals/step_test.rb`
- `test/models/manuals/progress_result_test.rb`
- `test/models/manuals/progress_test.rb`
- `test/components/manual/component_test.rb`
- `test/components/manual/hero/component_test.rb`
- `test/components/manual/flow_strip/component_test.rb`
- `test/components/manual/phase_section/component_test.rb`
- `test/components/manual/step_card/component_test.rb`
- `test/components/sidebar/component_test.rb` (modify — add 시작하기 그룹 회귀)
- `test/system/manuals_test.rb`

---

## Task 0: Confirm baseline green

**Purpose:** Make sure the baseline test suite is green before adding anything. Saves debugging time later.

- [ ] **Step 0.1: Run full suite**

Run: `bin/rails test`
Expected: All tests pass. If not, STOP and surface failures — do not proceed.

- [ ] **Step 0.2: Run system tests**

Run: `bin/rails test:system`
Expected: All system tests pass.

---

## Task 1: i18n locale file (structural, no logic)

**Files:**
- Create: `config/locales/manuals.ko.yml`

This is a **structural** commit — adds copy used by later tasks. No behavior change yet.

- [ ] **Step 1.1: Write the YAML file**

Create `config/locales/manuals.ko.yml`:

```yaml
ko:
  manuals:
    show:
      hero:
        headline: "경매 초보의 워크북"
        subhead: "낙찰 전 89개 체크리스트, 낙찰 후 명도 시뮬레이터"
        tagline: "정보를 보여드리는 게 아니라, 직접 분석하는 능력을 길러드립니다."
      continue_card:
        title: "이어서 하기"
        empty_title: "처음부터 시작하기"
        empty_body: "예산 설정부터 6단계로 안내해 드립니다."
      flow_strip:
        auction_marker: "낙찰"
      phase_pre:
        heading: "낙찰 전"
        subheading: "89개 체크리스트로 직접 분석합니다"
      phase_post:
        heading: "낙찰 후"
        subheading: "명도 시뮬레이터로 다음 한 수를 정합니다"
      footer:
        help_text: "각 화면에서 막히면 상단 도움말 아이콘을 눌러주세요."
    steps:
      budget:
        label: "예산 정하기"
        summary: "내가 살 수 있는 가격대를 먼저 못 박습니다."
        actions:
          - "보유 현금과 대출 한도 입력"
          - "취득세·수리비·이사비 등 부대비용 자동 계산"
          - "지역과 평형대 설정"
      properties:
        label: "물건 찾기"
        summary: "법원 경매 물건을 검색해서 내 목록에 담습니다."
        actions:
          - "법원 경매 사이트 검색 결과 가져오기"
          - "관심 물건 내 목록에 추가"
          - "예산 안 맞는 물건 자동 필터"
      ai_analysis:
        label: "AI 분석"
        summary: "권리관계와 위험요소를 AI가 1차로 정리합니다."
        actions:
          - "등기부·매각물건명세서 자동 분석"
          - "인수금액·말소기준권리 추출"
          - "이상 징후 하이라이트"
      checklist:
        label: "89개 체크리스트"
        summary: "AI 결과를 받아 직접 검증·보완합니다. 워크북의 핵심."
        actions:
          - "권리·물건·임차인·시세 등 89개 항목 점검"
          - "근거 문서 첨부와 메모"
          - "안전등급(녹/황/적) 자동 판정"
      eviction_guide:
        label: "명도 가이드"
        summary: "낙찰 후 점유자별 시나리오와 절차를 한 번에 봅니다."
        actions:
          - "점유자 유형별 흐름도"
          - "단계별 소요 기간·비용 가이드"
          - "필요 서류 체크"
      simulator:
        label: "명도 시뮬레이터"
        summary: "내 물건의 명도 난이도를 질문 답변으로 시뮬레이션합니다."
        actions:
          - "점유자 유형 선택"
          - "분기형 질문에 답하면 경로 제시"
          - "예상 기간·난이도 산출"
    cta:
      budget:
        default: "예산 설정 시작"
        in_progress: "예산 설정 이어서 하기"
      properties:
        default: "물건 추가하기"
      ai_analysis:
        default: "AI 분석할 물건 고르기"
        in_progress: "분석 이어서 하기"
      checklist:
        default: "체크리스트 시작"
        in_progress: "이어서 채우기 (%{done}/%{total})"
      eviction_guide:
        default: "명도 가이드 펴보기"
      simulator:
        default: "시뮬레이터 돌려보기"
        in_progress: "시뮬레이션 이어서 하기"
    status:
      done: "✓ 완료"
      in_progress: "▶ 진행 중"
      pending: "· 미시작"
```

- [ ] **Step 1.2: Smoke test that locale loads**

Run: `bin/rails runner 'puts I18n.t("manuals.show.hero.headline")'`
Expected: `경매 초보의 워크북`

- [ ] **Step 1.3: Run full suite (no regression)**

Run: `bin/rails test`
Expected: All pass.

- [ ] **Step 1.4: Commit (structural)**

```bash
git add config/locales/manuals.ko.yml
git commit -m "i18n(manuals): add ko locale for user manual page

Structural-only — no behavior wired up yet. Used by upcoming
ManualsController and Manual::* components."
```

---

## Task 2: Manuals::Step Data class

**Purpose:** Define the immutable record type used by `Progress` to describe each step.

**Files:**
- Create: `app/models/manuals/step.rb`
- Test: `test/models/manuals/step_test.rb`

- [ ] **Step 2.1: Write failing test**

Create `test/models/manuals/step_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

module Manuals
  class StepTest < ActiveSupport::TestCase
    test "exposes number, key, status, and detail" do
      step = Manuals::Step.new(number: 1, key: :budget, status: :done, detail: { foo: "bar" })

      assert_equal 1, step.number
      assert_equal :budget, step.key
      assert_equal :done, step.status
      assert_equal({ foo: "bar" }, step.detail)
    end

    test "is value-equal when fields match" do
      a = Manuals::Step.new(number: 1, key: :budget, status: :done, detail: nil)
      b = Manuals::Step.new(number: 1, key: :budget, status: :done, detail: nil)

      assert_equal a, b
    end

    test "status helpers" do
      done = Manuals::Step.new(number: 1, key: :budget, status: :done, detail: nil)
      progress = Manuals::Step.new(number: 1, key: :budget, status: :in_progress, detail: nil)
      pending = Manuals::Step.new(number: 1, key: :budget, status: :pending, detail: nil)
      none = Manuals::Step.new(number: 5, key: :eviction_guide, status: :none, detail: nil)

      assert done.done?
      assert progress.in_progress?
      assert pending.pending?
      assert none.none?
      refute done.in_progress?
    end
  end
end
```

- [ ] **Step 2.2: Run test, expect failure**

Run: `bin/rails test test/models/manuals/step_test.rb`
Expected: FAIL — `uninitialized constant Manuals::Step`.

- [ ] **Step 2.3: Implement Manuals::Step**

Create `app/models/manuals/step.rb`:

```ruby
# frozen_string_literal: true

module Manuals
  Step = Data.define(:number, :key, :status, :detail) do
    def done? = status == :done
    def in_progress? = status == :in_progress
    def pending? = status == :pending
    def none? = status == :none
  end
end
```

- [ ] **Step 2.4: Run test, expect pass**

Run: `bin/rails test test/models/manuals/step_test.rb`
Expected: 3 runs, 0 failures.

- [ ] **Step 2.5: Commit**

```bash
git add app/models/manuals/step.rb test/models/manuals/step_test.rb
git commit -m "feat(manuals): add Manuals::Step value class

Holds (number, key, status, detail) for one workflow step.
Exposes done?/in_progress?/pending?/none? predicates."
```

---

## Task 3: Manuals::ProgressResult Data class

**Purpose:** DTO returned by `Progress.for(user)` — what views consume.

**Files:**
- Create: `app/models/manuals/progress_result.rb`
- Test: `test/models/manuals/progress_result_test.rb`

- [ ] **Step 3.1: Write failing test**

Create `test/models/manuals/progress_result_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

module Manuals
  class ProgressResultTest < ActiveSupport::TestCase
    test "exposes steps, current_step, continue_cta" do
      step = Manuals::Step.new(number: 1, key: :budget, status: :pending, detail: nil)
      cta = { label: "예산 설정 시작", path: "/onboarding" }
      result = Manuals::ProgressResult.new(steps: [step], current_step: step, continue_cta: cta)

      assert_equal [step], result.steps
      assert_equal step, result.current_step
      assert_equal cta, result.continue_cta
    end

    test "fetch_step finds by key" do
      a = Manuals::Step.new(number: 1, key: :budget, status: :done, detail: nil)
      b = Manuals::Step.new(number: 4, key: :checklist, status: :in_progress, detail: { done: 12, total: 26 })
      result = Manuals::ProgressResult.new(steps: [a, b], current_step: b, continue_cta: nil)

      assert_equal b, result.fetch_step(:checklist)
      assert_nil result.fetch_step(:nonexistent)
    end
  end
end
```

- [ ] **Step 3.2: Run test, expect failure**

Run: `bin/rails test test/models/manuals/progress_result_test.rb`
Expected: FAIL — `uninitialized constant Manuals::ProgressResult`.

- [ ] **Step 3.3: Implement Manuals::ProgressResult**

Create `app/models/manuals/progress_result.rb`:

```ruby
# frozen_string_literal: true

module Manuals
  ProgressResult = Data.define(:steps, :current_step, :continue_cta) do
    def fetch_step(key)
      steps.find { |s| s.key == key }
    end
  end
end
```

- [ ] **Step 3.4: Run test, expect pass**

Run: `bin/rails test test/models/manuals/progress_result_test.rb`
Expected: 2 runs, 0 failures.

- [ ] **Step 3.5: Commit**

```bash
git add app/models/manuals/progress_result.rb test/models/manuals/progress_result_test.rb
git commit -m "feat(manuals): add Manuals::ProgressResult DTO

Carries steps array, current_step, and continue_cta hash.
fetch_step(key) for component lookups by symbol."
```

---

## Task 4: Manuals::Progress — step 1 (budget)

**Purpose:** Start the PORO. Add only step 1 logic — keep tasks small.

**Background:** `BudgetSetting` belongs_to user (uniqueness on user_id). `completed_at` is timestamp set when wizard finishes.

**Files:**
- Create: `app/models/manuals/progress.rb`
- Test: `test/models/manuals/progress_test.rb`

- [ ] **Step 4.1: Write failing tests**

Create `test/models/manuals/progress_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

module Manuals
  class ProgressTest < ActiveSupport::TestCase
    setup do
      @user = User.create!
    end

    # ---- Step 1: budget ----

    test "step 1 done when budget exists with completed_at" do
      BudgetSetting.create!(user: @user, available_cash: 1000, loan_ratio: 0.5, completed_at: Time.current)

      step = Manuals::Progress.for(@user).fetch_step(:budget)

      assert step.done?
    end

    test "step 1 in_progress when budget exists without completed_at" do
      BudgetSetting.create!(user: @user, available_cash: 1000, loan_ratio: 0.5, completed_at: nil)

      step = Manuals::Progress.for(@user).fetch_step(:budget)

      assert step.in_progress?
    end

    test "step 1 pending when no budget row" do
      step = Manuals::Progress.for(@user).fetch_step(:budget)

      assert step.pending?
    end
  end
end
```

- [ ] **Step 4.2: Run tests, expect failure**

Run: `bin/rails test test/models/manuals/progress_test.rb`
Expected: FAIL — `uninitialized constant Manuals::Progress`.

- [ ] **Step 4.3: Implement minimal Progress with step 1**

Create `app/models/manuals/progress.rb`:

```ruby
# frozen_string_literal: true

module Manuals
  class Progress
    STEP_DEFS = [
      { number: 1, key: :budget },
      { number: 2, key: :properties },
      { number: 3, key: :ai_analysis },
      { number: 4, key: :checklist },
      { number: 5, key: :eviction_guide },
      { number: 6, key: :simulator }
    ].freeze

    def self.for(user)
      new(user).result
    end

    def initialize(user)
      @user = user
    end

    def result
      ProgressResult.new(steps: build_steps, current_step: nil, continue_cta: nil)
    end

    private

    def build_steps
      STEP_DEFS.map { |defn| Step.new(number: defn[:number], key: defn[:key], status: status_for(defn[:key]), detail: detail_for(defn[:key])) }
    end

    def status_for(key)
      case key
      when :budget then budget_status
      else :pending
      end
    end

    def detail_for(_key) = nil

    def budget_status
      budget = BudgetSetting.find_by(user_id: @user.id)
      return :pending unless budget
      budget.completed_at.present? ? :done : :in_progress
    end
  end
end
```

- [ ] **Step 4.4: Run tests, expect pass**

Run: `bin/rails test test/models/manuals/progress_test.rb`
Expected: 3 runs, 0 failures.

- [ ] **Step 4.5: Commit**

```bash
git add app/models/manuals/progress.rb test/models/manuals/progress_test.rb
git commit -m "feat(manuals): Progress.for — step 1 (budget) status

Skeleton with all 6 step definitions; only :budget logic implemented.
Other steps return :pending placeholder until subsequent tasks."
```

---

## Task 5: Manuals::Progress — step 2 (properties)

**Background:** `UserProperty` join table with unique (user_id, property_id). Done if any row exists for the user.

**Files:**
- Modify: `app/models/manuals/progress.rb`
- Modify: `test/models/manuals/progress_test.rb`

- [ ] **Step 5.1: Add failing tests**

Append to `test/models/manuals/progress_test.rb` inside the class:

```ruby
    # ---- Step 2: properties ----

    test "step 2 done when user has at least one user_property" do
      property = Property.create!(case_number: "2026타경100001", court_name: "서울중앙지법", title: "테스트 물건")
      UserProperty.create!(user: @user, property: property)

      step = Manuals::Progress.for(@user).fetch_step(:properties)

      assert step.done?
    end

    test "step 2 pending when user has no user_properties" do
      step = Manuals::Progress.for(@user).fetch_step(:properties)

      assert step.pending?
    end
```

> If `Property.create!` fails because of required attributes you don't yet know about, run `bin/rails runner 'puts Property.new.tap(&:valid?).errors.full_messages'` to discover required fields, then add them. The case_number/court_name/title combo above is a guess based on auction domain — adjust as needed.

- [ ] **Step 5.2: Run tests, expect failure**

Run: `bin/rails test test/models/manuals/progress_test.rb -n /step.2/`
Expected: 2 failures — both expect non-pending or pending behavior we haven't built.

- [ ] **Step 5.3: Implement step 2 logic**

In `app/models/manuals/progress.rb`, replace the `status_for` method:

```ruby
    def status_for(key)
      case key
      when :budget then budget_status
      when :properties then properties_status
      else :pending
      end
    end
```

And add `properties_status` to the private section:

```ruby
    def properties_status
      UserProperty.exists?(user_id: @user.id) ? :done : :pending
    end
```

- [ ] **Step 5.4: Run tests, expect pass**

Run: `bin/rails test test/models/manuals/progress_test.rb`
Expected: 5 runs, 0 failures.

- [ ] **Step 5.5: Commit**

```bash
git add app/models/manuals/progress.rb test/models/manuals/progress_test.rb
git commit -m "feat(manuals): Progress — step 2 (properties)

Step 2 done if user has any user_property row, else pending."
```

---

## Task 6: Manuals::Progress — step 3 (ai_analysis)

**Background:** `UserProperty.analyzed_at` timestamp marks AI analysis completion for that user_property.

**Files:**
- Modify: `app/models/manuals/progress.rb`
- Modify: `test/models/manuals/progress_test.rb`

- [ ] **Step 6.1: Add failing tests**

Append inside the class:

```ruby
    # ---- Step 3: ai_analysis ----

    test "step 3 done when any user_property has analyzed_at set" do
      property = Property.create!(case_number: "2026타경100002", court_name: "서울중앙지법", title: "분석 완료 물건")
      UserProperty.create!(user: @user, property: property, analyzed_at: Time.current)

      step = Manuals::Progress.for(@user).fetch_step(:ai_analysis)

      assert step.done?
    end

    test "step 3 in_progress when user_property exists but no analyzed_at" do
      property = Property.create!(case_number: "2026타경100003", court_name: "서울중앙지법", title: "분석 미시작 물건")
      UserProperty.create!(user: @user, property: property, analyzed_at: nil)

      step = Manuals::Progress.for(@user).fetch_step(:ai_analysis)

      assert step.in_progress?
    end

    test "step 3 pending when no user_properties at all" do
      step = Manuals::Progress.for(@user).fetch_step(:ai_analysis)

      assert step.pending?
    end
```

- [ ] **Step 6.2: Run tests, expect failure**

Run: `bin/rails test test/models/manuals/progress_test.rb -n /step.3/`
Expected: 3 failures.

- [ ] **Step 6.3: Implement step 3 logic**

In `app/models/manuals/progress.rb`, extend `status_for`:

```ruby
    def status_for(key)
      case key
      when :budget then budget_status
      when :properties then properties_status
      when :ai_analysis then ai_analysis_status
      else :pending
      end
    end
```

Add `ai_analysis_status`:

```ruby
    def ai_analysis_status
      return :pending unless UserProperty.exists?(user_id: @user.id)
      UserProperty.where(user_id: @user.id).where.not(analyzed_at: nil).exists? ? :done : :in_progress
    end
```

- [ ] **Step 6.4: Run tests, expect pass**

Run: `bin/rails test test/models/manuals/progress_test.rb`
Expected: 8 runs, 0 failures.

- [ ] **Step 6.5: Commit**

```bash
git add app/models/manuals/progress.rb test/models/manuals/progress_test.rb
git commit -m "feat(manuals): Progress — step 3 (ai_analysis)

Done if any user_property.analyzed_at present, in_progress if
user_properties exist but none analyzed yet, pending otherwise."
```

---

## Task 7: Manuals::Progress — step 4 (89체크, multi-property safe)

**Background:** Spec mandates *single-property* aggregation to prevent A=40 + B=49 → ✓ false positive. Done when any single property has results for ALL `InspectionItem` rows. Threshold = `InspectionItem.count` (89 in prod, fewer in fixtures).

**Files:**
- Modify: `app/models/manuals/progress.rb`
- Modify: `test/models/manuals/progress_test.rb`

- [ ] **Step 7.1: Add failing tests (including multi-property edge cases)**

Append inside the class:

```ruby
    # ---- Step 4: checklist ----

    test "step 4 done when single property has results for ALL inspection_items" do
      property = Property.create!(case_number: "2026타경100004", court_name: "서울중앙지법", title: "전체 체크 완료 물건")
      UserProperty.create!(user: @user, property: property)
      InspectionItem.find_each do |item|
        InspectionResult.create!(user: @user, property: property, inspection_item: item, source_type: 0)
      end

      step = Manuals::Progress.for(@user).fetch_step(:checklist)

      assert step.done?
    end

    test "step 4 in_progress with single property max < total" do
      property = Property.create!(case_number: "2026타경100005", court_name: "서울중앙지법", title: "부분 체크")
      UserProperty.create!(user: @user, property: property)
      first_item = InspectionItem.first
      InspectionResult.create!(user: @user, property: property, inspection_item: first_item, source_type: 0)

      step = Manuals::Progress.for(@user).fetch_step(:checklist)

      assert step.in_progress?
      assert_equal 1, step.detail[:done]
      assert_equal InspectionItem.count, step.detail[:total]
    end

    test "step 4 pending when no inspection_results" do
      step = Manuals::Progress.for(@user).fetch_step(:checklist)

      assert step.pending?
    end

    test "step 4 NOT done when totals come from cross-property aggregation" do
      # CRITICAL spec rule: A=N + B=M never combines into done.
      half = InspectionItem.count / 2
      remainder = InspectionItem.count - half
      first_items = InspectionItem.limit(half)
      remaining_items = InspectionItem.offset(half).limit(remainder)
      property_a = Property.create!(case_number: "2026타경100006a", court_name: "서울중앙지법", title: "A")
      property_b = Property.create!(case_number: "2026타경100006b", court_name: "서울중앙지법", title: "B")
      UserProperty.create!(user: @user, property: property_a)
      UserProperty.create!(user: @user, property: property_b)
      first_items.each do |item|
        InspectionResult.create!(user: @user, property: property_a, inspection_item: item, source_type: 0)
      end
      remaining_items.each do |item|
        InspectionResult.create!(user: @user, property: property_b, inspection_item: item, source_type: 0)
      end

      step = Manuals::Progress.for(@user).fetch_step(:checklist)

      refute step.done?, "Cross-property aggregation must not flip checklist to done"
      assert step.in_progress?
      assert_equal [ half, remainder ].max, step.detail[:done], "Progress count is the single-property max, not the sum"
    end

    test "step 4 done when one property full and another partial" do
      property_full = Property.create!(case_number: "2026타경100007", court_name: "서울중앙지법", title: "Full")
      property_partial = Property.create!(case_number: "2026타경100007b", court_name: "서울중앙지법", title: "Partial")
      UserProperty.create!(user: @user, property: property_full)
      UserProperty.create!(user: @user, property: property_partial)
      InspectionItem.find_each do |item|
        InspectionResult.create!(user: @user, property: property_full, inspection_item: item, source_type: 0)
      end
      InspectionResult.create!(user: @user, property: property_partial, inspection_item: InspectionItem.first, source_type: 0)

      step = Manuals::Progress.for(@user).fetch_step(:checklist)

      assert step.done?
    end
```

- [ ] **Step 7.2: Run tests, expect failure**

Run: `bin/rails test test/models/manuals/progress_test.rb -n /step.4/`
Expected: 5 failures.

- [ ] **Step 7.3: Implement step 4 logic**

In `app/models/manuals/progress.rb`, extend `status_for`:

```ruby
    def status_for(key)
      case key
      when :budget then budget_status
      when :properties then properties_status
      when :ai_analysis then ai_analysis_status
      when :checklist then checklist_status
      else :pending
      end
    end
```

Replace `detail_for`:

```ruby
    def detail_for(key)
      case key
      when :checklist then checklist_detail
      end
    end
```

Add private helpers:

```ruby
    def checklist_status
      max = checklist_max_per_property
      total = checklist_total
      return :pending if max.zero?
      max >= total ? :done : :in_progress
    end

    def checklist_detail
      { done: checklist_max_per_property, total: checklist_total }
    end

    def checklist_max_per_property
      return @checklist_max_per_property if defined?(@checklist_max_per_property)

      counts = InspectionResult
        .where(user_id: @user.id, property_id: UserProperty.where(user_id: @user.id).select(:property_id))
        .group(:property_id)
        .distinct
        .count(:inspection_item_id)
      @checklist_max_per_property = counts.values.max || 0
    end

    def checklist_total
      @checklist_total ||= InspectionItem.count
    end
```

- [ ] **Step 7.4: Run tests, expect pass**

Run: `bin/rails test test/models/manuals/progress_test.rb`
Expected: 13 runs, 0 failures.

- [ ] **Step 7.5: Commit**

```bash
git add app/models/manuals/progress.rb test/models/manuals/progress_test.rb
git commit -m "feat(manuals): Progress — step 4 (checklist) with multi-property guard

Done iff a single user_property has results for every InspectionItem.
Cross-property sums never flip status; in_progress detail reports
the single-property max so '49/89' label stays accurate."
```

---

## Task 8: Manuals::Progress — step 5 (eviction_guide) + step 6 (simulator)

**Background:** Step 5 deliberately untracked (status: `:none`). Step 6 uses `EvictionSimulation.completed` boolean; presence-with-incomplete = ▶, completed = ✓.

**Files:**
- Modify: `app/models/manuals/progress.rb`
- Modify: `test/models/manuals/progress_test.rb`

- [ ] **Step 8.1: Add failing tests**

Append inside the class:

```ruby
    # ---- Step 5: eviction_guide ----

    test "step 5 has status :none regardless of state" do
      step = Manuals::Progress.for(@user).fetch_step(:eviction_guide)

      assert step.none?
    end

    # ---- Step 6: simulator ----

    test "step 6 done when user has completed simulation" do
      property = Property.create!(case_number: "2026타경100008", court_name: "서울중앙지법", title: "시뮬 완료")
      UserProperty.create!(user: @user, property: property)
      EvictionSimulation.create!(property: property, completed: true, occupant_type: "owner", answers: {})

      step = Manuals::Progress.for(@user).fetch_step(:simulator)

      assert step.done?
    end

    test "step 6 in_progress when simulation exists but not completed" do
      property = Property.create!(case_number: "2026타경100009", court_name: "서울중앙지법", title: "시뮬 진행")
      UserProperty.create!(user: @user, property: property)
      EvictionSimulation.create!(property: property, completed: false, occupant_type: "owner", answers: {})

      step = Manuals::Progress.for(@user).fetch_step(:simulator)

      assert step.in_progress?
    end

    test "step 6 pending when no simulation" do
      step = Manuals::Progress.for(@user).fetch_step(:simulator)

      assert step.pending?
    end
```

> `EvictionSimulation` may or may not require additional fields. If `create!` fails, inspect with `bin/rails runner 'puts EvictionSimulation.new.tap(&:valid?).errors.full_messages'` and add what's needed.

- [ ] **Step 8.2: Run tests, expect failure**

Run: `bin/rails test test/models/manuals/progress_test.rb -n /(step.5|step.6)/`
Expected: 4 failures.

- [ ] **Step 8.3: Implement step 5 + 6 logic**

In `app/models/manuals/progress.rb`, finalize `status_for`:

```ruby
    def status_for(key)
      case key
      when :budget then budget_status
      when :properties then properties_status
      when :ai_analysis then ai_analysis_status
      when :checklist then checklist_status
      when :eviction_guide then :none
      when :simulator then simulator_status
      end
    end
```

Add helper:

```ruby
    def simulator_status
      simulations = EvictionSimulation.where(property_id: UserProperty.where(user_id: @user.id).select(:property_id))
      return :pending unless simulations.exists?
      simulations.where(completed: true).exists? ? :done : :in_progress
    end
```

- [ ] **Step 8.4: Run tests, expect pass**

Run: `bin/rails test test/models/manuals/progress_test.rb`
Expected: 17 runs, 0 failures.

- [ ] **Step 8.5: Commit**

```bash
git add app/models/manuals/progress.rb test/models/manuals/progress_test.rb
git commit -m "feat(manuals): Progress — step 5 (untracked) + step 6 (simulator)

Step 5 always returns :none — eviction guide status is intentionally
not tracked per spec. Step 6 maps EvictionSimulation.completed."
```

---

## Task 9: Manuals::Progress — current_step + continue_cta

**Background:** Per spec, current_step = first non-done step in 1→6 order, **skipping :none status (step 5)**. CTA mapping is the table from spec — owned by `Progress` here so the controller can read a finished result. Step 4 CTA target = property_id of `inspection_results.updated_at` MAX (fallback to last user_property).

**Files:**
- Modify: `app/models/manuals/progress.rb`
- Modify: `test/models/manuals/progress_test.rb`

- [ ] **Step 9.1: Add failing tests**

Append inside the class:

```ruby
    # ---- current_step ----

    test "current_step is step 1 for fresh user (all pending)" do
      result = Manuals::Progress.for(@user)

      assert_equal :budget, result.current_step.key
    end

    test "current_step skips done steps and lands on first non-done non-:none step" do
      BudgetSetting.create!(user: @user, available_cash: 1000, loan_ratio: 0.5, completed_at: Time.current)
      property = Property.create!(case_number: "2026타경100010", court_name: "서울중앙지법", title: "OK")
      UserProperty.create!(user: @user, property: property)

      result = Manuals::Progress.for(@user)

      assert_equal :ai_analysis, result.current_step.key
    end

    test "current_step lands on simulator when 1-4 done and step 5 skipped" do
      BudgetSetting.create!(user: @user, available_cash: 1000, loan_ratio: 0.5, completed_at: Time.current)
      property = Property.create!(case_number: "2026타경100011", court_name: "서울중앙지법", title: "Full")
      UserProperty.create!(user: @user, property: property, analyzed_at: Time.current)
      InspectionItem.find_each do |item|
        InspectionResult.create!(user: @user, property: property, inspection_item: item, source_type: 0)
      end

      result = Manuals::Progress.for(@user)

      assert_equal :simulator, result.current_step.key
    end

    # ---- continue_cta ----

    test "continue_cta for fresh user points to onboarding start" do
      result = Manuals::Progress.for(@user)

      assert_equal :budget, result.continue_cta[:key]
      assert_equal :pending, result.continue_cta[:variant]
    end

    test "continue_cta for in_progress checklist carries property_id from latest inspection_result" do
      property_old = Property.create!(case_number: "2026타경100012a", court_name: "서울중앙지법", title: "Old")
      property_new = Property.create!(case_number: "2026타경100012b", court_name: "서울중앙지법", title: "New")
      UserProperty.create!(user: @user, property: property_old)
      UserProperty.create!(user: @user, property: property_new)
      BudgetSetting.create!(user: @user, available_cash: 1000, loan_ratio: 0.5, completed_at: Time.current)
      UserProperty.where(user: @user).update_all(analyzed_at: Time.current)

      InspectionResult.create!(user: @user, property: property_old, inspection_item: InspectionItem.first, source_type: 0, updated_at: 2.days.ago)
      InspectionResult.create!(user: @user, property: property_new, inspection_item: InspectionItem.second, source_type: 0, updated_at: 1.minute.ago)

      result = Manuals::Progress.for(@user)
      cta = result.continue_cta

      assert_equal :checklist, cta[:key]
      assert_equal :in_progress, cta[:variant]
      assert_equal property_new.id, cta[:property_id], "Step 4 CTA must target the property with the latest inspection_result.updated_at"
    end
```

- [ ] **Step 9.2: Run tests, expect failure**

Run: `bin/rails test test/models/manuals/progress_test.rb -n /(current_step|continue_cta)/`
Expected: 5 failures.

- [ ] **Step 9.3: Implement current_step + continue_cta**

In `app/models/manuals/progress.rb`, replace `result`:

```ruby
    def result
      built = build_steps
      current = pick_current_step(built)
      ProgressResult.new(steps: built, current_step: current, continue_cta: build_continue_cta(current))
    end
```

Add private helpers:

```ruby
    def pick_current_step(built_steps)
      built_steps.find { |s| s.status != :done && s.status != :none } || built_steps.last
    end

    def build_continue_cta(step)
      base = { key: step.key, variant: cta_variant(step) }
      case step.key
      when :checklist then base.merge(property_id: latest_inspection_property_id || latest_user_property_id)
      else base
      end
    end

    def cta_variant(step)
      step.in_progress? ? :in_progress : :pending
    end

    def latest_inspection_property_id
      InspectionResult.where(user_id: @user.id, property_id: UserProperty.where(user_id: @user.id).select(:property_id))
        .order(updated_at: :desc).limit(1).pick(:property_id)
    end

    def latest_user_property_id
      UserProperty.where(user_id: @user.id).order(updated_at: :desc).limit(1).pick(:property_id)
    end
```

- [ ] **Step 9.4: Run tests, expect pass**

Run: `bin/rails test test/models/manuals/progress_test.rb`
Expected: 22 runs, 0 failures.

- [ ] **Step 9.5: Commit**

```bash
git add app/models/manuals/progress.rb test/models/manuals/progress_test.rb
git commit -m "feat(manuals): Progress — current_step + continue_cta

current_step is first step whose status is neither :done nor :none.
continue_cta carries (key, variant) for label/path resolution; for
:checklist it also carries property_id from the latest
inspection_result.updated_at (fallback: latest user_property)."
```

---

## Task 10: ManualsController + route + view shell

**Purpose:** Wire the controller. Render an empty-but-valid HTML so we can system-test the URL.

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/manuals_controller.rb`
- Create: `app/views/manuals/show.html.erb`
- Create: `test/controllers/manuals_controller_test.rb`

- [ ] **Step 10.1: Write failing controller test**

Create `test/controllers/manuals_controller_test.rb`:

```ruby
require "test_helper"

class ManualsControllerTest < ActionDispatch::IntegrationTest
  test "GET /manual returns 200 and assigns progress" do
    get manual_url

    assert_response :success
    assert_kind_of Manuals::ProgressResult, assigns(:progress)
  end

  test "GET /manual auto-creates a guest user (no auth gate)" do
    assert_difference "User.count", 1 do
      get manual_url
    end
  end
end
```

- [ ] **Step 10.2: Run, expect failure**

Run: `bin/rails test test/controllers/manuals_controller_test.rb`
Expected: FAIL — `undefined method manual_url` or routing error.

- [ ] **Step 10.3: Add route**

In `config/routes.rb`, add this line near the existing top-level resources (e.g., right after `resources :search_results...` block, before `scope :eviction_guide ...`):

```ruby
  resource :manual, only: [ :show ]
```

- [ ] **Step 10.4: Add controller**

Create `app/controllers/manuals_controller.rb`:

```ruby
class ManualsController < ApplicationController
  def show
    @progress = Manuals::Progress.for(current_user)
  end
end
```

- [ ] **Step 10.5: Add view shell (placeholder content)**

Create `app/views/manuals/show.html.erb`:

```erb
<%# Placeholder until Manual::Component is wired in Task 16. %>
<h1><%= t("manuals.show.hero.headline") %></h1>
```

- [ ] **Step 10.6: Run controller tests, expect pass**

Run: `bin/rails test test/controllers/manuals_controller_test.rb`
Expected: 2 runs, 0 failures.

- [ ] **Step 10.7: Run full suite (no regression)**

Run: `bin/rails test`
Expected: All pass.

- [ ] **Step 10.8: Commit**

```bash
git add config/routes.rb app/controllers/manuals_controller.rb app/views/manuals/show.html.erb test/controllers/manuals_controller_test.rb
git commit -m "feat(manuals): add ManualsController#show + route

GET /manual renders Manuals::ProgressResult into @progress. View is
a placeholder until Manual::Component lands."
```

---

## Task 11: Manual::StepCard component

**Purpose:** Single accordion card for one step. Maps `step.key` + `step.status` to CTA path/label and renders i18n actions list. Uses native `<details>`.

**Files:**
- Create: `app/components/manual/step_card/component.rb`
- Create: `app/components/manual/step_card/component.html.erb`
- Create: `test/components/manual/step_card/component_test.rb`

- [ ] **Step 11.1: Write failing tests**

Create `test/components/manual/step_card/component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

module Manual
  module StepCard
    class ComponentTest < ViewComponent::TestCase
      test "renders label and summary from i18n" do
        step = Manuals::Step.new(number: 1, key: :budget, status: :pending, detail: nil)

        render_inline(Manual::StepCard::Component.new(step: step, default_open: false))

        assert_text "예산 정하기"
        assert_text "내가 살 수 있는 가격대를 먼저 못 박습니다."
      end

      test "is collapsed when default_open is false" do
        step = Manuals::Step.new(number: 1, key: :budget, status: :pending, detail: nil)

        render_inline(Manual::StepCard::Component.new(step: step, default_open: false))

        assert_no_selector "details[open]"
        assert_selector "details"
      end

      test "is open when default_open is true" do
        step = Manuals::Step.new(number: 1, key: :budget, status: :pending, detail: nil)

        render_inline(Manual::StepCard::Component.new(step: step, default_open: true))

        assert_selector "details[open]"
      end

      test "renders status icon for trackable step" do
        step = Manuals::Step.new(number: 1, key: :budget, status: :done, detail: nil)

        render_inline(Manual::StepCard::Component.new(step: step, default_open: false))

        assert_text "✓ 완료"
      end

      test "omits status icon for :none status (eviction guide)" do
        step = Manuals::Step.new(number: 5, key: :eviction_guide, status: :none, detail: nil)

        render_inline(Manual::StepCard::Component.new(step: step, default_open: false))

        assert_no_text "완료"
        assert_no_text "진행 중"
        assert_no_text "미시작"
      end

      test "checklist in_progress CTA shows progress count" do
        step = Manuals::Step.new(number: 4, key: :checklist, status: :in_progress, detail: { done: 12, total: 26 })

        render_inline(Manual::StepCard::Component.new(step: step, default_open: true))

        assert_text "이어서 채우기 (12/26)"
      end

      test "renders actions list from i18n" do
        step = Manuals::Step.new(number: 1, key: :budget, status: :pending, detail: nil)

        render_inline(Manual::StepCard::Component.new(step: step, default_open: true))

        assert_text "보유 현금과 대출 한도 입력"
        assert_text "취득세·수리비·이사비 등 부대비용 자동 계산"
        assert_text "지역과 평형대 설정"
      end

      test "CTA links to the right path per step key" do
        step = Manuals::Step.new(number: 2, key: :properties, status: :pending, detail: nil)

        render_inline(Manual::StepCard::Component.new(step: step, default_open: true))

        assert_selector "a[href='/properties']"
      end
    end
  end
end
```

- [ ] **Step 11.2: Run, expect failure**

Run: `bin/rails test test/components/manual/step_card/component_test.rb`
Expected: FAIL — `uninitialized constant Manual::StepCard`.

- [ ] **Step 11.3: Implement component class**

Create `app/components/manual/step_card/component.rb`:

```ruby
# frozen_string_literal: true

module Manual
  module StepCard
    class Component < ViewComponent::Base
      def initialize(step:, default_open: false)
        @step = step
        @default_open = default_open
      end

      private

      attr_reader :step

      def open?
        @default_open
      end

      def label
        t("manuals.steps.#{step.key}.label")
      end

      def summary
        t("manuals.steps.#{step.key}.summary")
      end

      def actions
        t("manuals.steps.#{step.key}.actions")
      end

      def status_text
        return nil if step.none?
        t("manuals.status.#{step.status}")
      end

      def cta_label
        if step.in_progress? && step.key == :checklist && step.detail
          t("manuals.cta.checklist.in_progress", done: step.detail[:done], total: step.detail[:total])
        elsif step.in_progress?
          t("manuals.cta.#{step.key}.in_progress", default: t("manuals.cta.#{step.key}.default"))
        else
          t("manuals.cta.#{step.key}.default")
        end
      end

      def cta_path
        case step.key
        when :budget then helpers.start_onboarding_path
        when :properties then helpers.properties_path
        when :ai_analysis then helpers.properties_path
        when :checklist then helpers.properties_path
        when :eviction_guide then helpers.eviction_guide_guide_path
        when :simulator then helpers.eviction_guide_simulator_path
        end
      end

      def screenshot_path
        "manual/0#{step.number}-#{step.key.to_s.dasherize}.png"
      end
    end
  end
end
```

- [ ] **Step 11.4: Implement template**

Create `app/components/manual/step_card/component.html.erb`:

```erb
<details class="rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 p-4 mb-3" <%= "open" if open? %>>
  <summary class="cursor-pointer flex items-center gap-3">
    <span class="text-lg font-semibold text-slate-700 dark:text-slate-200">
      <%= step.number %>. <%= label %>
    </span>
    <% if status_text %>
      <span class="ml-auto text-sm text-slate-500 dark:text-slate-400"><%= status_text %></span>
    <% end %>
  </summary>
  <p class="mt-3 text-slate-600 dark:text-slate-300"><%= summary %></p>
  <ul class="mt-3 list-disc list-inside text-slate-600 dark:text-slate-300 space-y-1">
    <% actions.each do |action| %>
      <li><%= action %></li>
    <% end %>
  </ul>
  <%= image_tag(screenshot_path, alt: label, class: "mt-4 rounded border border-slate-200 dark:border-slate-700", onerror: "this.style.display='none'") %>
  <a href="<%= cta_path %>" class="mt-4 inline-block bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">
    <%= cta_label %>
  </a>
</details>
```

> The `onerror` swallow on the screenshot lets the page render cleanly during dev when assets are still placeholders. Once Task 18 lands the real screenshots, the attribute can stay (defense in depth) or be removed.

- [ ] **Step 11.5: Run tests, expect pass**

Run: `bin/rails test test/components/manual/step_card/component_test.rb`
Expected: 8 runs, 0 failures.

- [ ] **Step 11.6: Commit**

```bash
git add app/components/manual/step_card test/components/manual/step_card
git commit -m "feat(manuals): Manual::StepCard accordion component

Native <details> accordion. Maps step.key to CTA path/label and
i18n copy. Hides status text for :none-status steps (eviction guide)."
```

---

## Task 12: Manual::FlowStrip component

**Purpose:** 6-box horizontal strip with auction marker between #4 and #5.

**Files:**
- Create: `app/components/manual/flow_strip/component.rb`
- Create: `app/components/manual/flow_strip/component.html.erb`
- Create: `test/components/manual/flow_strip/component_test.rb`

- [ ] **Step 12.1: Write failing tests**

Create `test/components/manual/flow_strip/component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

module Manual
  module FlowStrip
    class ComponentTest < ViewComponent::TestCase
      def steps_fixture
        [
          Manuals::Step.new(number: 1, key: :budget, status: :done, detail: nil),
          Manuals::Step.new(number: 2, key: :properties, status: :in_progress, detail: nil),
          Manuals::Step.new(number: 3, key: :ai_analysis, status: :pending, detail: nil),
          Manuals::Step.new(number: 4, key: :checklist, status: :pending, detail: nil),
          Manuals::Step.new(number: 5, key: :eviction_guide, status: :none, detail: nil),
          Manuals::Step.new(number: 6, key: :simulator, status: :pending, detail: nil)
        ]
      end

      test "renders all 6 step labels" do
        render_inline(Manual::FlowStrip::Component.new(steps: steps_fixture, current_step_key: :properties))

        assert_text "예산 정하기"
        assert_text "물건 찾기"
        assert_text "AI 분석"
        assert_text "89개 체크리스트"
        assert_text "명도 가이드"
        assert_text "명도 시뮬레이터"
      end

      test "renders auction marker between steps 4 and 5" do
        render_inline(Manual::FlowStrip::Component.new(steps: steps_fixture, current_step_key: :properties))

        assert_text "낙찰"
      end

      test "marks current step box" do
        render_inline(Manual::FlowStrip::Component.new(steps: steps_fixture, current_step_key: :properties))

        assert_selector "[data-current-step='properties']"
      end

      test "shows status icon for all steps except :none" do
        render_inline(Manual::FlowStrip::Component.new(steps: steps_fixture, current_step_key: :properties))

        # 5 trackable steps × at least one of (✓/▶/·)
        assert_text "✓"
        assert_text "▶"
        assert_text "·"
      end
    end
  end
end
```

- [ ] **Step 12.2: Run, expect failure**

Run: `bin/rails test test/components/manual/flow_strip/component_test.rb`
Expected: FAIL — `uninitialized constant Manual::FlowStrip`.

- [ ] **Step 12.3: Implement component**

Create `app/components/manual/flow_strip/component.rb`:

```ruby
# frozen_string_literal: true

module Manual
  module FlowStrip
    class Component < ViewComponent::Base
      AUCTION_MARKER_AFTER = 4

      def initialize(steps:, current_step_key:)
        @steps = steps
        @current_step_key = current_step_key
      end

      private

      attr_reader :steps, :current_step_key

      def label_for(step)
        t("manuals.steps.#{step.key}.label")
      end

      def status_icon(step)
        return nil if step.none?
        case step.status
        when :done then "✓"
        when :in_progress then "▶"
        when :pending then "·"
        end
      end

      def auction_marker
        t("manuals.show.flow_strip.auction_marker")
      end

      def current?(step)
        step.key == current_step_key
      end
    end
  end
end
```

Create `app/components/manual/flow_strip/component.html.erb`:

```erb
<div class="flex items-center gap-2 overflow-x-auto py-3">
  <% steps.each do |step| %>
    <div class="flex items-center gap-1 px-3 py-2 rounded border <%= current?(step) ? 'border-blue-500 bg-blue-50 dark:bg-blue-900/30' : 'border-slate-200 dark:border-slate-700' %>"
         data-current-step="<%= step.key if current?(step) %>">
      <% if (icon = status_icon(step)) %>
        <span class="text-slate-500 dark:text-slate-400"><%= icon %></span>
      <% end %>
      <span class="text-sm text-slate-700 dark:text-slate-200"><%= step.number %>. <%= label_for(step) %></span>
    </div>
    <% if step.number == AUCTION_MARKER_AFTER %>
      <span class="px-2 text-xs font-semibold text-amber-600 dark:text-amber-400 border-l-2 border-amber-400 pl-3">
        <%= auction_marker %>
      </span>
    <% elsif step.number < steps.length %>
      <span class="text-slate-300 dark:text-slate-600">→</span>
    <% end %>
  <% end %>
</div>
```

- [ ] **Step 12.4: Run tests, expect pass**

Run: `bin/rails test test/components/manual/flow_strip/component_test.rb`
Expected: 4 runs, 0 failures.

- [ ] **Step 12.5: Commit**

```bash
git add app/components/manual/flow_strip test/components/manual/flow_strip
git commit -m "feat(manuals): Manual::FlowStrip 6-box workflow strip

Renders 6 steps left-to-right with auction marker between #4 and #5.
Step 5 (eviction guide) has no status icon — intentional per spec."
```

---

## Task 13: Manual::Hero component

**Purpose:** Headline + subhead + tagline + "이어서 하기" card.

**Files:**
- Create: `app/components/manual/hero/component.rb`
- Create: `app/components/manual/hero/component.html.erb`
- Create: `test/components/manual/hero/component_test.rb`

- [ ] **Step 13.1: Write failing tests**

Create `test/components/manual/hero/component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

module Manual
  module Hero
    class ComponentTest < ViewComponent::TestCase
      def progress_fixture(current_key: :budget, cta_extra: {})
        step = Manuals::Step.new(number: 1, key: current_key, status: :pending, detail: nil)
        cta = { key: current_key, variant: :pending }.merge(cta_extra)
        Manuals::ProgressResult.new(steps: [step], current_step: step, continue_cta: cta)
      end

      test "renders headline, subhead, and tagline" do
        render_inline(Manual::Hero::Component.new(progress: progress_fixture))

        assert_text "경매 초보의 워크북"
        assert_text "낙찰 전 89개 체크리스트, 낙찰 후 명도 시뮬레이터"
        assert_text "정보를 보여드리는 게 아니라, 직접 분석하는 능력을 길러드립니다."
      end

      test "renders continue card with current step CTA" do
        render_inline(Manual::Hero::Component.new(progress: progress_fixture(current_key: :budget)))

        assert_text "이어서 하기"
        assert_selector "a[href='/onboarding']", text: "예산 설정 시작"
      end

      test "renders fallback when current_step is nil" do
        empty = Manuals::ProgressResult.new(steps: [], current_step: nil, continue_cta: nil)

        render_inline(Manual::Hero::Component.new(progress: empty))

        assert_text "처음부터 시작하기"
      end
    end
  end
end
```

- [ ] **Step 13.2: Run, expect failure**

Run: `bin/rails test test/components/manual/hero/component_test.rb`
Expected: FAIL.

- [ ] **Step 13.3: Implement component**

Create `app/components/manual/hero/component.rb`:

```ruby
# frozen_string_literal: true

module Manual
  module Hero
    class Component < ViewComponent::Base
      def initialize(progress:)
        @progress = progress
      end

      private

      attr_reader :progress

      def has_current?
        progress.current_step.present?
      end

      def cta_card_step
        progress.current_step
      end

      def cta_card_label
        return nil unless has_current?
        Manual::StepCard::Component.new(step: cta_card_step, default_open: false).send(:cta_label)
      end

      def cta_card_path
        return nil unless has_current?
        Manual::StepCard::Component.new(step: cta_card_step, default_open: false).send(:cta_path)
      end

      def fallback_path
        helpers.start_onboarding_path
      end
    end
  end
end
```

> Reusing `StepCard`'s private cta resolution via `send` keeps mapping in one place. If this becomes painful, extract a `Manual::CtaResolver` PORO in a refactor commit — out of scope for this task.

Create `app/components/manual/hero/component.html.erb`:

```erb
<section class="grid grid-cols-1 lg:grid-cols-3 gap-6 py-8">
  <div class="lg:col-span-2">
    <h1 class="text-3xl font-bold text-slate-900 dark:text-slate-100">
      <%= t("manuals.show.hero.headline") %>
    </h1>
    <p class="mt-2 text-lg text-slate-700 dark:text-slate-200">
      <%= t("manuals.show.hero.subhead") %>
    </p>
    <p class="mt-2 text-sm text-slate-500 dark:text-slate-400">
      <%= t("manuals.show.hero.tagline") %>
    </p>
  </div>
  <aside class="rounded-lg border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 p-4">
    <% if has_current? %>
      <h2 class="text-sm font-semibold text-slate-600 dark:text-slate-300"><%= t("manuals.show.continue_card.title") %></h2>
      <p class="mt-1 text-base text-slate-900 dark:text-slate-100"><%= t("manuals.steps.#{cta_card_step.key}.label") %></p>
      <a href="<%= cta_card_path %>" class="mt-3 inline-block bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">
        <%= cta_card_label %>
      </a>
    <% else %>
      <h2 class="text-sm font-semibold text-slate-600 dark:text-slate-300"><%= t("manuals.show.continue_card.empty_title") %></h2>
      <p class="mt-1 text-sm text-slate-500 dark:text-slate-400"><%= t("manuals.show.continue_card.empty_body") %></p>
      <a href="<%= fallback_path %>" class="mt-3 inline-block bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">
        <%= t("manuals.show.continue_card.empty_title") %>
      </a>
    <% end %>
  </aside>
</section>
```

- [ ] **Step 13.4: Run, expect pass**

Run: `bin/rails test test/components/manual/hero/component_test.rb`
Expected: 3 runs, 0 failures.

- [ ] **Step 13.5: Commit**

```bash
git add app/components/manual/hero test/components/manual/hero
git commit -m "feat(manuals): Manual::Hero with continue card

Headline/subhead/tagline + 'continue from where you left off' card
on the right. Falls back to 'start over' CTA when no current step."
```

---

## Task 14: Manual::PhaseSection component

**Purpose:** Section header (낙찰 전 / 낙찰 후) with 4 or 2 step cards inside.

**Files:**
- Create: `app/components/manual/phase_section/component.rb`
- Create: `app/components/manual/phase_section/component.html.erb`
- Create: `test/components/manual/phase_section/component_test.rb`

- [ ] **Step 14.1: Write failing tests**

Create `test/components/manual/phase_section/component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

module Manual
  module PhaseSection
    class ComponentTest < ViewComponent::TestCase
      def fixture_steps
        (1..6).map { |n| Manuals::Step.new(number: n, key: :budget, status: :pending, detail: nil) }
      end

      test "renders pre-auction heading and step cards" do
        steps = fixture_steps.first(4)

        render_inline(Manual::PhaseSection::Component.new(phase: :pre, steps: steps, current_step_key: :budget))

        assert_text "낙찰 전"
        assert_text "89개 체크리스트로 직접 분석합니다"
      end

      test "renders post-auction heading and step cards" do
        steps = fixture_steps.last(2)

        render_inline(Manual::PhaseSection::Component.new(phase: :post, steps: steps, current_step_key: :simulator))

        assert_text "낙찰 후"
        assert_text "명도 시뮬레이터로 다음 한 수를 정합니다"
      end

      test "opens only the current step card by default" do
        budget_done = Manuals::Step.new(number: 1, key: :budget, status: :done, detail: nil)
        properties_pending = Manuals::Step.new(number: 2, key: :properties, status: :pending, detail: nil)

        render_inline(Manual::PhaseSection::Component.new(phase: :pre, steps: [budget_done, properties_pending], current_step_key: :properties))

        # Only one <details open> in output
        assert_selector "details[open]", count: 1
      end
    end
  end
end
```

- [ ] **Step 14.2: Run, expect failure**

Run: `bin/rails test test/components/manual/phase_section/component_test.rb`
Expected: FAIL.

- [ ] **Step 14.3: Implement component**

Create `app/components/manual/phase_section/component.rb`:

```ruby
# frozen_string_literal: true

module Manual
  module PhaseSection
    class Component < ViewComponent::Base
      def initialize(phase:, steps:, current_step_key:)
        @phase = phase
        @steps = steps
        @current_step_key = current_step_key
      end

      private

      attr_reader :phase, :steps, :current_step_key

      def heading
        t("manuals.show.phase_#{phase}.heading")
      end

      def subheading
        t("manuals.show.phase_#{phase}.subheading")
      end
    end
  end
end
```

Create `app/components/manual/phase_section/component.html.erb`:

```erb
<section class="py-6">
  <header class="mb-4">
    <h2 class="text-2xl font-bold text-slate-900 dark:text-slate-100"><%= heading %></h2>
    <p class="text-sm text-slate-500 dark:text-slate-400 mt-1"><%= subheading %></p>
  </header>
  <% steps.each do |step| %>
    <%= render Manual::StepCard::Component.new(step: step, default_open: step.key == current_step_key) %>
  <% end %>
</section>
```

- [ ] **Step 14.4: Run, expect pass**

Run: `bin/rails test test/components/manual/phase_section/component_test.rb`
Expected: 3 runs, 0 failures.

- [ ] **Step 14.5: Commit**

```bash
git add app/components/manual/phase_section test/components/manual/phase_section
git commit -m "feat(manuals): Manual::PhaseSection wraps step cards

Renders the pre/post-auction section header and delegates each
step to StepCard. Only the current step card opens by default."
```

---

## Task 15: Manual::Component (page assembly)

**Purpose:** Compose Hero + FlowStrip + PhaseSection×2 + footer.

**Files:**
- Create: `app/components/manual/component.rb`
- Create: `app/components/manual/component.html.erb`
- Create: `test/components/manual/component_test.rb`

- [ ] **Step 15.1: Write failing tests**

Create `test/components/manual/component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

module Manual
  class ComponentTest < ViewComponent::TestCase
    def progress_fixture
      steps = [
        Manuals::Step.new(number: 1, key: :budget, status: :done, detail: nil),
        Manuals::Step.new(number: 2, key: :properties, status: :in_progress, detail: nil),
        Manuals::Step.new(number: 3, key: :ai_analysis, status: :pending, detail: nil),
        Manuals::Step.new(number: 4, key: :checklist, status: :pending, detail: nil),
        Manuals::Step.new(number: 5, key: :eviction_guide, status: :none, detail: nil),
        Manuals::Step.new(number: 6, key: :simulator, status: :pending, detail: nil)
      ]
      Manuals::ProgressResult.new(steps: steps, current_step: steps[1], continue_cta: { key: :properties, variant: :pending })
    end

    test "renders hero, flow strip, both phase sections, footer" do
      render_inline(Manual::Component.new(progress: progress_fixture))

      assert_text "경매 초보의 워크북"      # hero
      assert_text "낙찰"                    # flow strip auction marker
      assert_text "낙찰 전"                 # pre-auction heading
      assert_text "낙찰 후"                 # post-auction heading
      assert_text "각 화면에서 막히면"      # footer
    end

    test "splits steps 1-4 into pre and 5-6 into post" do
      render_inline(Manual::Component.new(progress: progress_fixture))

      # 4 step cards in pre + 2 in post = 6 total
      assert_selector "details", count: 6
    end
  end
end
```

- [ ] **Step 15.2: Run, expect failure**

Run: `bin/rails test test/components/manual/component_test.rb`
Expected: FAIL.

- [ ] **Step 15.3: Implement component**

Create `app/components/manual/component.rb`:

```ruby
# frozen_string_literal: true

module Manual
  class Component < ViewComponent::Base
    def initialize(progress:)
      @progress = progress
    end

    private

    attr_reader :progress

    def pre_auction_steps
      progress.steps.first(4)
    end

    def post_auction_steps
      progress.steps.last(2)
    end

    def current_step_key
      progress.current_step&.key
    end
  end
end
```

Create `app/components/manual/component.html.erb`:

```erb
<article class="max-w-5xl mx-auto px-4 lg:px-8">
  <%= render Manual::Hero::Component.new(progress: progress) %>
  <%= render Manual::FlowStrip::Component.new(steps: progress.steps, current_step_key: current_step_key) %>
  <%= render Manual::PhaseSection::Component.new(phase: :pre, steps: pre_auction_steps, current_step_key: current_step_key) %>
  <%= render Manual::PhaseSection::Component.new(phase: :post, steps: post_auction_steps, current_step_key: current_step_key) %>
  <footer class="py-6 text-sm text-slate-500 dark:text-slate-400">
    <%= t("manuals.show.footer.help_text") %>
  </footer>
</article>
```

- [ ] **Step 15.4: Run, expect pass**

Run: `bin/rails test test/components/manual/component_test.rb`
Expected: 2 runs, 0 failures.

- [ ] **Step 15.5: Commit**

```bash
git add app/components/manual/component.rb app/components/manual/component.html.erb test/components/manual/component_test.rb
git commit -m "feat(manuals): Manual::Component page assembly

Composes Hero + FlowStrip + PhaseSection×2 + footer. Splits steps
1-4 into pre-auction phase and 5-6 into post-auction phase."
```

---

## Task 16: Wire Manual::Component into the view

**Purpose:** Replace placeholder view with the assembled component.

**Files:**
- Modify: `app/views/manuals/show.html.erb`

- [ ] **Step 16.1: Replace view content**

Replace `app/views/manuals/show.html.erb` with:

```erb
<%= render Manual::Component.new(progress: @progress) %>
```

- [ ] **Step 16.2: Run controller test (regression)**

Run: `bin/rails test test/controllers/manuals_controller_test.rb`
Expected: All pass.

- [ ] **Step 16.3: Manual smoke check**

Run: `bin/rails server` (in a separate terminal — leave running)
Visit: `http://localhost:3000/manual` in a browser
Expected: Hero, flow strip, pre/post sections, and 6 step cards visible. The current-step card is open. (Stop the server when done.)

- [ ] **Step 16.4: Commit**

```bash
git add app/views/manuals/show.html.erb
git commit -m "feat(manuals): wire Manual::Component into show view"
```

---

## Task 17: Sidebar — add 시작하기 group

**Purpose:** Add the new sidebar group at the top, with the user manual entry.

**Background:** Sidebar uses `MENU_GROUPS` constant — a Hash that preserves insertion order. New entry must be the first key.

**Files:**
- Modify: `app/components/sidebar/component.rb`
- Modify: `test/components/sidebar/component_test.rb`

- [ ] **Step 17.1: Add failing tests for the new group**

Add inside `module Sidebar; class ComponentTest`:

```ruby
    # --- 시작하기 group ---

    test "renders 사용자매뉴얼 menu item" do
      render_inline(Sidebar::Component.new)

      assert_text "사용자매뉴얼"
      assert_selector "a[href='/manual']", text: "사용자매뉴얼"
    end

    test "사용자매뉴얼 is the first link in the sidebar (시작하기 group is at top)" do
      render_inline(Sidebar::Component.new)

      first_link = page.first("a[href]")
      assert_equal "/manual", first_link[:href]
    end

    test "marks 사용자매뉴얼 as active when on /manual" do
      render_inline(Sidebar::Component.new(current_path: "/manual"))

      assert_selector "a[href='/manual'][class*='bg-blue-50']"
    end
```

- [ ] **Step 17.2: Run, expect failure**

Run: `bin/rails test test/components/sidebar/component_test.rb`
Expected: 3 new failures.

- [ ] **Step 17.3: Update sidebar**

In `app/components/sidebar/component.rb`, modify the `MENU_GROUPS` constant. Replace:

```ruby
    MENU_GROUPS = {
      "물건검색" => [
```

With:

```ruby
    MENU_GROUPS = {
      "시작하기" => [
        MenuItem.new(label: "사용자매뉴얼", icon: "book-open", path: :manual_path, enabled: true)
      ],
      "물건검색" => [
```

> Heroicon `book-open` is already used by 명도 가이드. If you'd prefer a distinct icon, `academic-cap` or `map` are reasonable; doesn't affect tests.

- [ ] **Step 17.4: Run sidebar tests, expect pass**

Run: `bin/rails test test/components/sidebar/component_test.rb`
Expected: All pass.

- [ ] **Step 17.5: Run full suite (regression)**

Run: `bin/rails test`
Expected: All pass.

- [ ] **Step 17.6: Commit**

```bash
git add app/components/sidebar/component.rb test/components/sidebar/component_test.rb
git commit -m "feat(sidebar): add 시작하기 group with 사용자매뉴얼

Pinned at the top so it's the first thing new users see.
Reuses book-open icon (shared with 명도 가이드)."
```

---

## Task 18: System test — full happy path

**Purpose:** End-to-end check that sidebar entry → /manual → expected content works.

**Files:**
- Create: `test/system/manuals_test.rb`

- [ ] **Step 18.1: Write the system test**

Create `test/system/manuals_test.rb`:

```ruby
require "application_system_test_case"

class ManualsTest < ApplicationSystemTestCase
  test "신규 사용자가 사이드바에서 사용자매뉴얼을 열면 hero와 step 1이 펼쳐져 있다" do
    visit "/manual"

    assert_text "경매 초보의 워크북"
    assert_text "낙찰 전 89개 체크리스트, 낙찰 후 명도 시뮬레이터"

    # current_step = budget (1번) for fresh user
    within("section", text: "낙찰 전") do
      assert_selector "details[open]", text: "예산 정하기"
    end

    # Continue card CTA points to onboarding
    assert_selector "a[href='/onboarding']", text: "예산 설정 시작"
  end

  test "사이드바 사용자매뉴얼 클릭 시 /manual로 이동한다" do
    visit "/properties"

    click_on "사용자매뉴얼"

    assert_current_path "/manual"
    assert_text "경매 초보의 워크북"
  end

  test "예산을 완료한 사용자는 step 2가 펼쳐져 있다" do
    visit "/manual"  # creates guest session
    user = User.find(page.driver.request.session[:user_id]) if page.driver.respond_to?(:request)
    user ||= User.last  # fallback for capybara drivers without direct session access
    BudgetSetting.create!(user: user, available_cash: 30_000, loan_ratio: 0.7, completed_at: Time.current)

    visit "/manual"

    within("section", text: "낙찰 전") do
      assert_selector "details[open]", text: "물건 찾기"
    end
  end
end
```

> The third test's `user` lookup relies on the guest auto-creation (`ensure_current_user`). If session access via `page.driver.request` isn't reliable in your Capybara driver, the `User.last` fallback works because the test runs in isolation. If both fail, swap to the existing pattern (e.g., post `/testing/sign_in` like in `auth/sessions_controller_test.rb`).

- [ ] **Step 18.2: Run system tests**

Run: `bin/rails test:system test/system/manuals_test.rb`
Expected: 3 runs, 0 failures.

- [ ] **Step 18.3: Commit**

```bash
git add test/system/manuals_test.rb
git commit -m "test(manuals): system test — sidebar to manual page happy path

Covers fresh-user landing, sidebar nav, and progress-aware default
open card after budget completion."
```

---

## Task 19: Placeholder screenshots + final QA

**Purpose:** Avoid broken `<img>` boxes in dev. Real screenshots are out of scope; placeholders unblock UI rendering.

**Files:**
- Create: 6 placeholder PNG files under `app/assets/images/manual/`

- [ ] **Step 19.1: Create placeholder directory + transparent 1×1 PNGs**

Run from project root:

```bash
mkdir -p app/assets/images/manual
for n in 01-budget 02-properties 03-ai-analysis 04-checklist 05-eviction-guide 06-simulator; do
  printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xf8\xcf\xc0\x00\x00\x00\x03\x00\x01\xa6\x0e\x18\x9c\x00\x00\x00\x00IEND\xaeB`\x82' > "app/assets/images/manual/${n}.png"
done
```

> These are valid 1×1 transparent PNGs. They render nothing visible but won't 404. Real screenshots are added in a follow-up task.

- [ ] **Step 19.2: Run full suite + system tests**

Run: `bin/rails test && bin/rails test:system`
Expected: All pass.

- [ ] **Step 19.3: Manual browser QA**

Run: `bin/rails server`
Visit `/manual` and exercise:
- Sidebar shows "시작하기 > 사용자매뉴얼" at the top
- Hero copy reads correctly (헤드라인/부제/tagline)
- Flow strip shows 6 boxes with auction marker between #4 and #5
- Step 1 card is open by default for fresh user
- CTA buttons in each step card link to the right page
- Light/dark mode both look reasonable

If any visual issue surfaces, fix in a follow-up commit (Tailwind class adjustments only — no behavior change).

- [ ] **Step 19.4: Commit**

```bash
git add app/assets/images/manual
git commit -m "chore(manuals): add placeholder screenshots

1×1 transparent PNGs so step card <img> tags don't 404 in dev.
Real screenshots will replace these in a follow-up task."
```

---

## Task 20: Final pre-PR check

- [ ] **Step 20.1: Run linters / pre-commit hooks if configured**

Run: `bin/rubocop` (if used) and `bin/rails test:all` if defined.
Expected: Clean.

- [ ] **Step 20.2: Inspect git log**

Run: `git log --oneline main..HEAD`
Expected: ~16 small commits, each green at its own point. Structural and behavioral commits separated (i18n was structural-only; everything else was paired test+impl).

- [ ] **Step 20.3: Hand-off**

Plan complete. Use the push2gh skill to open the PR per project convention.

---

## Out-of-Scope Reminders

These are **not** part of this plan and must not creep in:

- Real screenshot capture (separate task)
- Help-icon implementation per screen (footer copy mentions it, but the icon work is not included)
- "필수 항목 N개" softening of step 4 (Risks section in spec — defer until prod data warrants it)
- Multi-locale i18n
- Stimulus accordion (we use native `<details>`)
- Any new database column or migration

## Risks Carried Forward

- **89 ✓ definition strictness:** "fill all 89" is hard. If usage data shows it locks users, revisit per spec Risks section.
- **Linear current_step rule:** if user fills step 4 to 30/89 and completes step 6, current_step stays 4 forever. Acceptable per spec.
- **Screenshot maintenance:** UI changes will desync the 6 PNGs. Mitigation: each card has a CTA to the live screen, so the screenshot is supportive, not load-bearing.
