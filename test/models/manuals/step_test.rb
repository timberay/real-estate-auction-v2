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
