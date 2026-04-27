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
  end
end
