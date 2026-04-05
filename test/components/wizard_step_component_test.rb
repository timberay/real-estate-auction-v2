# frozen_string_literal: true

require "test_helper"

class WizardStepComponentTest < ViewComponent::TestCase
  # --- Basic rendering ---

  test "renders title" do
    render_inline(WizardStepComponent.new(title: "기본 정보", current_step: 1, total_steps: 3)) { "Step content" }

    assert_text "기본 정보"
    assert_text "Step content"
  end

  # --- Progress dots ---

  test "renders correct number of progress dots" do
    render_inline(WizardStepComponent.new(title: "Title", current_step: 2, total_steps: 4)) { "Content" }

    assert_selector "div[class*='rounded-full']", count: 4
  end

  test "marks current step with ring" do
    render_inline(WizardStepComponent.new(title: "Title", current_step: 2, total_steps: 3)) { "Content" }

    html = page.native.inner_html
    assert_includes html, "ring"
  end

  test "past and current steps have active color" do
    render_inline(WizardStepComponent.new(title: "Title", current_step: 2, total_steps: 3)) { "Content" }

    assert_selector "div[class*='bg-blue-600']", minimum: 2
  end

  test "future steps have inactive color" do
    render_inline(WizardStepComponent.new(title: "Title", current_step: 1, total_steps: 3)) { "Content" }

    assert_selector "div[class*='bg-slate-200']", minimum: 2
  end

  # --- Description ---

  test "renders description when provided" do
    render_inline(WizardStepComponent.new(
      title: "Title", current_step: 1, total_steps: 3, description: "설명 텍스트"
    )) { "Content" }

    assert_text "설명 텍스트"
    html = page.native.inner_html
    assert_includes html, "text-slate-500"
  end

  test "does not render description when not provided" do
    render_inline(WizardStepComponent.new(title: "Title", current_step: 1, total_steps: 3)) { "Content" }

    assert_no_selector "p[class*='text-slate-500']"
  end

  # --- Container ---

  test "renders max-w-lg wrapper" do
    render_inline(WizardStepComponent.new(title: "Title", current_step: 1, total_steps: 3)) { "Content" }

    assert_selector "div[class*='max-w-lg']"
    assert_selector "div[class*='mx-auto']"
  end

  # --- Title styling ---

  test "title has correct styling" do
    render_inline(WizardStepComponent.new(title: "Title", current_step: 1, total_steps: 3)) { "Content" }

    html = page.native.inner_html
    assert_includes html, "text-2xl"
    assert_includes html, "font-bold"
  end

  # --- Dark mode ---

  test "includes dark mode classes on title" do
    render_inline(WizardStepComponent.new(title: "Title", current_step: 1, total_steps: 3)) { "Content" }

    html = page.native.inner_html
    assert_includes html, "dark:text-slate-100"
  end

  test "includes dark mode classes on description" do
    render_inline(WizardStepComponent.new(
      title: "Title", current_step: 1, total_steps: 3, description: "Desc"
    )) { "Content" }

    html = page.native.inner_html
    assert_includes html, "dark:text-slate-400"
  end
end
