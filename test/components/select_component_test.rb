# frozen_string_literal: true

require "test_helper"

class SelectComponentTest < ViewComponent::TestCase
  # --- Basic rendering ---

  test "renders with label and select" do
    render_inline(SelectComponent.new(label: "지역", name: "region")) do |select|
      select.with_option(value: "seoul", label: "서울")
      select.with_option(value: "busan", label: "부산")
    end

    assert_selector "label", text: "지역"
    assert_selector "label[class*='text-sm']"
    assert_selector "label[class*='font-medium']"
    assert_selector "select[name='region']"
    assert_selector "option[value='seoul']", text: "서울"
    assert_selector "option[value='busan']", text: "부산"
  end

  # --- Prompt ---

  test "renders prompt option" do
    render_inline(SelectComponent.new(label: "지역", name: "region", prompt: "선택하세요")) do |select|
      select.with_option(value: "seoul", label: "서울")
    end

    assert_selector "option[value='']", text: "선택하세요"
  end

  # --- Required ---

  test "renders required mark and attribute" do
    render_inline(SelectComponent.new(label: "지역", name: "region", required: true)) do |select|
      select.with_option(value: "seoul", label: "서울")
    end

    assert_selector "span.text-red-500", text: "*"
    assert_selector "select[required]"
  end

  # --- Error state ---

  test "renders error message and error styling" do
    render_inline(SelectComponent.new(label: "지역", name: "region", error: "필수 항목입니다")) do |select|
      select.with_option(value: "seoul", label: "서울")
    end

    assert_selector "p[class*='text-red-600']", text: "필수 항목입니다"
    assert_selector "select[class*='border-red-500']"
  end

  # --- Selected option ---

  test "renders selected option" do
    render_inline(SelectComponent.new(label: "지역", name: "region")) do |select|
      select.with_option(value: "seoul", label: "서울")
      select.with_option(value: "busan", label: "부산", selected: true)
    end

    assert_selector "option[value='busan'][selected]", text: "부산"
  end

  # --- Size ---

  test "renders default md size with py-2.5" do
    render_inline(SelectComponent.new(label: "지역", name: "region")) do |select|
      select.with_option(value: "seoul", label: "서울")
    end

    assert_selector "select[class*='py-2.5']"
  end

  test "renders sm size with py-1.5" do
    render_inline(SelectComponent.new(label: "지역", name: "region", size: :sm)) do |select|
      select.with_option(value: "seoul", label: "서울")
    end

    assert_selector "select[class*='py-1.5']"
  end

  test "renders lg size with py-3" do
    render_inline(SelectComponent.new(label: "지역", name: "region", size: :lg)) do |select|
      select.with_option(value: "seoul", label: "서울")
    end

    assert_selector "select[class*='py-3']"
  end

  # --- Dark mode ---

  test "includes dark mode classes" do
    render_inline(SelectComponent.new(label: "지역", name: "region")) do |select|
      select.with_option(value: "seoul", label: "서울")
    end

    assert_selector "label[class*='dark:text-slate-300']"
    assert_selector "select[class*='dark:border-slate-600']"
    assert_selector "select[class*='dark:bg-slate-700']"
  end

  test "includes dark mode classes on error" do
    render_inline(SelectComponent.new(label: "지역", name: "region", error: "에러")) do |select|
      select.with_option(value: "seoul", label: "서울")
    end

    assert_selector "p[class*='dark:text-red-400']"
  end
end
