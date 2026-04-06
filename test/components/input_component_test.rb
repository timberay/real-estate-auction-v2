# frozen_string_literal: true

require "test_helper"

class InputComponentTest < ViewComponent::TestCase
  # --- Basic rendering ---

  test "renders with label and input" do
    render_inline(InputComponent.new(label: "이름", name: "name"))

    assert_selector "label", text: "이름"
    assert_selector "label[class*='text-sm']"
    assert_selector "label[class*='font-medium']"
    assert_selector "label[class*='text-slate-700']"
    assert_selector "input[name='name']"
    assert_selector "input[type='text']"
  end

  # --- Required mark ---

  test "renders required mark when required" do
    render_inline(InputComponent.new(label: "이름", name: "name", required: true))

    assert_selector "span.text-red-500", text: "*"
    assert_selector "input[required]"
  end

  test "does not render required mark when not required" do
    render_inline(InputComponent.new(label: "이름", name: "name"))

    assert_no_selector "span.text-red-500"
    assert_no_selector "input[required]"
  end

  # --- Suffix ---

  test "renders suffix when provided" do
    render_inline(InputComponent.new(label: "금액", name: "amount", suffix: "원"))

    assert_text "원"
    assert_selector "div[class*='flex']"
    assert_selector "span[class*='text-slate-600']", text: "원"
  end

  # --- Error state ---

  test "renders error message and error styling" do
    render_inline(InputComponent.new(label: "이름", name: "name", error: "필수 항목입니다"))

    assert_selector "p[class*='text-red-600']", text: "필수 항목입니다"
    assert_selector "input[class*='border-red-500']"
  end

  test "does not render help text when error is present" do
    render_inline(InputComponent.new(label: "이름", name: "name", error: "에러", help_text: "도움말"))

    assert_text "에러"
    assert_no_text "도움말"
  end

  # --- Help text ---

  test "renders help text when no error" do
    render_inline(InputComponent.new(label: "이름", name: "name", help_text: "도움말 텍스트"))

    assert_selector "p[class*='text-slate-500']", text: "도움말 텍스트"
  end

  # --- Dark mode ---

  test "includes dark mode classes" do
    render_inline(InputComponent.new(label: "이름", name: "name"))

    assert_selector "label[class*='dark:text-slate-300']"
    assert_selector "input[class*='dark:border-slate-600']"
    assert_selector "input[class*='dark:bg-slate-700']"
  end

  test "includes dark mode classes on error message" do
    render_inline(InputComponent.new(label: "이름", name: "name", error: "에러"))

    assert_selector "p[class*='dark:text-red-400']"
  end

  test "includes dark mode classes on help text" do
    render_inline(InputComponent.new(label: "이름", name: "name", help_text: "도움말"))

    assert_selector "p[class*='dark:text-slate-400']"
  end

  test "includes dark mode classes on suffix" do
    render_inline(InputComponent.new(label: "금액", name: "amount", suffix: "원"))

    assert_selector "span[class*='dark:text-slate-400']"
  end

  # --- Inputmode ---

  test "renders inputmode attribute" do
    render_inline(InputComponent.new(label: "금액", name: "amount", inputmode: "numeric"))

    assert_selector "input[inputmode='numeric']"
  end

  # --- Placeholder ---

  test "renders placeholder attribute" do
    render_inline(InputComponent.new(label: "이름", name: "name", placeholder: "이름을 입력하세요"))

    assert_selector "input[placeholder='이름을 입력하세요']"
  end

  # --- Value ---

  test "renders value attribute" do
    render_inline(InputComponent.new(label: "이름", name: "name", value: "홍길동"))

    assert_selector "input[value='홍길동']"
  end

  # --- Size ---

  test "renders default md size with py-2.5" do
    render_inline(InputComponent.new(label: "이름", name: "name"))

    assert_selector "input[class*='py-2.5']"
  end

  test "renders sm size with py-1.5" do
    render_inline(InputComponent.new(label: "이름", name: "name", size: :sm))

    assert_selector "input[class*='py-1.5']"
  end

  test "renders lg size with py-3" do
    render_inline(InputComponent.new(label: "이름", name: "name", size: :lg))

    assert_selector "input[class*='py-3']"
  end

  # --- Focus ring ---

  test "input has focus ring classes" do
    render_inline(InputComponent.new(label: "이름", name: "name"))

    assert_selector "input[class*='focus:ring-2']"
    assert_selector "input[class*='focus:ring-blue-500/20']"
  end
end
