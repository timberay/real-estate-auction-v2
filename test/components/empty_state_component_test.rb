# frozen_string_literal: true

require "test_helper"

class EmptyStateComponentTest < ViewComponent::TestCase
  # --- Basic rendering ---

  test "renders icon, title, and description" do
    render_inline(EmptyStateComponent.new(
      icon: "document-text",
      title: "데이터가 없습니다",
      description: "아직 등록된 항목이 없습니다."
    ))

    assert_text "데이터가 없습니다"
    assert_text "아직 등록된 항목이 없습니다."
    assert_selector "div[class*='flex']"
    assert_selector "div[class*='flex-col']"
    assert_selector "div[class*='items-center']"
    assert_selector "div[class*='justify-center']"
    assert_selector "div[class*='py-16']"
  end

  # --- Icon ---

  test "renders icon with correct size" do
    render_inline(EmptyStateComponent.new(
      icon: "document-text",
      title: "없음",
      description: "설명"
    ))

    html = page.native.inner_html
    assert_includes html, "w-12"
    assert_includes html, "h-12"
    assert_includes html, "text-slate-300"
  end

  # --- Title styling ---

  test "renders title with correct styling" do
    render_inline(EmptyStateComponent.new(
      icon: "document-text",
      title: "제목",
      description: "설명"
    ))

    html = page.native.inner_html
    assert_includes html, "text-lg"
    assert_includes html, "font-semibold"
  end

  test "renders title as h2 (a11y heading order)" do
    render_inline(EmptyStateComponent.new(
      icon: "document-text",
      title: "제목",
      description: "설명"
    ))

    assert_selector "h2", text: "제목"
  end

  # --- Description styling ---

  test "renders description with correct styling" do
    render_inline(EmptyStateComponent.new(
      icon: "document-text",
      title: "제목",
      description: "설명 텍스트"
    ))

    html = page.native.inner_html
    assert_includes html, "text-center"
    assert_includes html, "max-w-sm"
  end

  # --- CTA button ---

  test "renders CTA button when cta_text and cta_href provided" do
    render_inline(EmptyStateComponent.new(
      icon: "document-text",
      title: "없음",
      description: "설명",
      cta_text: "새로 만들기",
      cta_href: "/items/new"
    ))

    assert_text "새로 만들기"
    assert_selector "a[href='/items/new']"
  end

  test "does not render CTA when cta_text is missing" do
    render_inline(EmptyStateComponent.new(
      icon: "document-text",
      title: "없음",
      description: "설명",
      cta_href: "/items/new"
    ))

    assert_no_selector "a[href='/items/new']"
  end

  test "does not render CTA when cta_href is missing" do
    render_inline(EmptyStateComponent.new(
      icon: "document-text",
      title: "없음",
      description: "설명",
      cta_text: "새로 만들기"
    ))

    assert_no_selector "a"
  end

  # --- Dark mode ---

  test "includes dark mode classes on icon" do
    render_inline(EmptyStateComponent.new(
      icon: "document-text",
      title: "없음",
      description: "설명"
    ))

    html = page.native.inner_html
    assert_includes html, "dark:text-slate-600"
  end

  test "includes dark mode classes on title" do
    render_inline(EmptyStateComponent.new(
      icon: "document-text",
      title: "없음",
      description: "설명"
    ))

    html = page.native.inner_html
    assert_includes html, "dark:text-slate-300"
  end

  test "includes dark mode classes on description" do
    render_inline(EmptyStateComponent.new(
      icon: "document-text",
      title: "없음",
      description: "설명"
    ))

    html = page.native.inner_html
    assert_includes html, "dark:text-slate-400"
  end
end
