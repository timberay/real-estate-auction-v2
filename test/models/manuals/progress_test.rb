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
