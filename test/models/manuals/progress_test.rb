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

    # ---- Step 2: properties ----

    test "step 2 done when user has at least one user_property" do
      property = Property.create!(case_number: "2026타경100001")
      UserProperty.create!(user: @user, property: property)

      step = Manuals::Progress.for(@user).fetch_step(:properties)

      assert step.done?
    end

    test "step 2 pending when user has no user_properties" do
      step = Manuals::Progress.for(@user).fetch_step(:properties)

      assert step.pending?
    end

    # ---- Step 3: ai_analysis ----

    test "step 3 done when any user_property has analyzed_at set" do
      property = Property.create!(case_number: "2026타경100002")
      UserProperty.create!(user: @user, property: property, analyzed_at: Time.current)

      step = Manuals::Progress.for(@user).fetch_step(:ai_analysis)

      assert step.done?
    end

    test "step 3 in_progress when user_property exists but no analyzed_at" do
      property = Property.create!(case_number: "2026타경100003")
      UserProperty.create!(user: @user, property: property, analyzed_at: nil)

      step = Manuals::Progress.for(@user).fetch_step(:ai_analysis)

      assert step.in_progress?
    end

    test "step 3 pending when no user_properties at all" do
      step = Manuals::Progress.for(@user).fetch_step(:ai_analysis)

      assert step.pending?
    end

    # ---- Step 4: checklist ----

    test "step 4 done when single property has results for ALL inspection_items" do
      property = Property.create!(case_number: "2026타경100004")
      UserProperty.create!(user: @user, property: property)
      InspectionItem.find_each do |item|
        InspectionResult.create!(user: @user, property: property, inspection_item: item, source_type: 0)
      end

      step = Manuals::Progress.for(@user).fetch_step(:checklist)

      assert step.done?
    end

    test "step 4 in_progress with single property max < total" do
      property = Property.create!(case_number: "2026타경100005")
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
      property_a = Property.create!(case_number: "2026타경100006a")
      property_b = Property.create!(case_number: "2026타경100006b")
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
      property_full = Property.create!(case_number: "2026타경100007")
      property_partial = Property.create!(case_number: "2026타경100007b")
      UserProperty.create!(user: @user, property: property_full)
      UserProperty.create!(user: @user, property: property_partial)
      InspectionItem.find_each do |item|
        InspectionResult.create!(user: @user, property: property_full, inspection_item: item, source_type: 0)
      end
      InspectionResult.create!(user: @user, property: property_partial, inspection_item: InspectionItem.first, source_type: 0)

      step = Manuals::Progress.for(@user).fetch_step(:checklist)

      assert step.done?
    end

    # ---- Step 5: eviction_guide ----

    test "step 5 has status :none regardless of state" do
      step = Manuals::Progress.for(@user).fetch_step(:eviction_guide)

      assert step.none?
    end

    # ---- Step 6: simulator ----

    test "step 6 done when user has completed simulation" do
      property = Property.create!(case_number: "2026타경100008")
      UserProperty.create!(user: @user, property: property)
      EvictionSimulation.create!(property: property, completed: true, occupant_type: "debtor_owner", answers: {})

      step = Manuals::Progress.for(@user).fetch_step(:simulator)

      assert step.done?
    end

    test "step 6 in_progress when simulation exists but not completed" do
      property = Property.create!(case_number: "2026타경100009")
      UserProperty.create!(user: @user, property: property)
      EvictionSimulation.create!(property: property, completed: false, occupant_type: "debtor_owner", answers: {})

      step = Manuals::Progress.for(@user).fetch_step(:simulator)

      assert step.in_progress?
    end

    test "step 6 pending when no simulation" do
      step = Manuals::Progress.for(@user).fetch_step(:simulator)

      assert step.pending?
    end
  end
end
