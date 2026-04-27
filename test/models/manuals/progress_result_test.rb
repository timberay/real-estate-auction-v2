# frozen_string_literal: true

require "test_helper"

module Manuals
  class ProgressResultTest < ActiveSupport::TestCase
    test "exposes steps, current_step, continue_cta" do
      step = Manuals::Step.new(number: 1, key: :budget, status: :pending, detail: nil)
      cta = { label: "예산 설정 시작", path: "/onboarding" }
      result = Manuals::ProgressResult.new(steps: [ step ], current_step: step, continue_cta: cta)

      assert_equal [ step ], result.steps
      assert_equal step, result.current_step
      assert_equal cta, result.continue_cta
    end

    test "fetch_step finds by key" do
      a = Manuals::Step.new(number: 1, key: :budget, status: :done, detail: nil)
      b = Manuals::Step.new(number: 4, key: :checklist, status: :in_progress, detail: { done: 12, total: 26 })
      result = Manuals::ProgressResult.new(steps: [ a, b ], current_step: b, continue_cta: nil)

      assert_equal b, result.fetch_step(:checklist)
      assert_nil result.fetch_step(:nonexistent)
    end
  end
end
