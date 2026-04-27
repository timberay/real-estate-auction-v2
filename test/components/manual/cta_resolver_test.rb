# frozen_string_literal: true

require "test_helper"

module Manual
  class CtaResolverTest < ActiveSupport::TestCase
    setup do
      @original_locale = I18n.locale
      I18n.locale = :ko
    end

    teardown { I18n.locale = @original_locale }

    def step(key:, status:, detail: nil)
      Manuals::Step.new(number: 1, key: key, status: status, detail: detail)
    end

    # ---- path ----

    test "path for :budget returns /onboarding" do
      assert_equal "/onboarding", Manual::CtaResolver.new(step(key: :budget, status: :pending)).path
    end

    test "path for :properties returns /properties" do
      assert_equal "/properties", Manual::CtaResolver.new(step(key: :properties, status: :pending)).path
    end

    test "path for :ai_analysis returns /analyses/new (matches sidebar)" do
      assert_equal "/analyses/new", Manual::CtaResolver.new(step(key: :ai_analysis, status: :pending)).path
    end

    test "path for :checklist returns /properties" do
      assert_equal "/properties", Manual::CtaResolver.new(step(key: :checklist, status: :pending)).path
    end

    test "path for :eviction_guide returns /eviction_guide" do
      assert_equal "/eviction_guide", Manual::CtaResolver.new(step(key: :eviction_guide, status: :none)).path
    end

    test "path for :simulator returns /eviction_guide/simulator" do
      assert_equal "/eviction_guide/simulator", Manual::CtaResolver.new(step(key: :simulator, status: :pending)).path
    end

    # ---- label ----

    test "pending step returns default cta label" do
      assert_equal "예산 설정 시작", Manual::CtaResolver.new(step(key: :budget, status: :pending)).label
    end

    test "in_progress step returns in_progress label when key has one" do
      assert_equal "예산 설정 이어서 하기", Manual::CtaResolver.new(step(key: :budget, status: :in_progress)).label
    end

    test "in_progress step falls back to default when no in_progress key (e.g. properties)" do
      # :properties has only `default`, no `in_progress` translation key
      assert_equal "물건 추가하기", Manual::CtaResolver.new(step(key: :properties, status: :in_progress)).label
    end

    test "checklist in_progress with detail interpolates done/total" do
      result = Manual::CtaResolver.new(step(key: :checklist, status: :in_progress, detail: { done: 12, total: 26 })).label
      assert_equal "이어서 채우기 (12/26)", result
    end

    test "checklist in_progress without detail falls back to default label (no placeholder leak)" do
      result = Manual::CtaResolver.new(step(key: :checklist, status: :in_progress, detail: nil)).label
      assert_equal "체크리스트 시작", result
      refute_match(/%\{/, result, "placeholder must never reach the user")
    end

    test "done step returns default label" do
      assert_equal "예산 설정 시작", Manual::CtaResolver.new(step(key: :budget, status: :done)).label
    end

    # ---- step_label ----

    test "step_label returns the i18n step label" do
      assert_equal "예산 정하기", Manual::CtaResolver.new(step(key: :budget, status: :pending)).step_label
    end

    # ---- path with property_id (deep link) ----

    test "checklist path with property_id deep links to property page" do
      resolver = Manual::CtaResolver.new(step(key: :checklist, status: :in_progress, detail: { done: 12, total: 26 }), property_id: 42)
      assert_equal "/properties/42", resolver.path
    end

    test "checklist path without property_id falls back to /properties list" do
      resolver = Manual::CtaResolver.new(step(key: :checklist, status: :in_progress, detail: { done: 12, total: 26 }))
      assert_equal "/properties", resolver.path
    end

    test "non-checklist key ignores property_id" do
      resolver = Manual::CtaResolver.new(step(key: :budget, status: :pending), property_id: 99)
      assert_equal "/onboarding", resolver.path
    end
  end
end
