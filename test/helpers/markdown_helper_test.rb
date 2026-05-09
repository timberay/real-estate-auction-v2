# frozen_string_literal: true

require "test_helper"

class MarkdownHelperTest < ActionView::TestCase
  test "renders basic markdown headings" do
    html = markdown("# Title\n\n## Subtitle")
    assert_match %r{<h1>Title</h1>}, html
    assert_match %r{<h2>Subtitle</h2>}, html
  end

  test "filters raw HTML tags (XSS guard)" do
    html = markdown("<script>alert(1)</script>")
    refute_match %r{<script>}, html
  end

  test "filters inline event handlers (XSS guard)" do
    html = markdown("<img src=x onerror=alert(1)>")
    refute_match %r{onerror}, html
  end

  test "blocks javascript: links" do
    html = markdown("[click](javascript:alert(1))")
    refute_match %r{href="javascript:}, html
  end

  test "renders https links" do
    html = markdown("[example](https://example.com)")
    assert_match %r{<a href="https://example\.com">example</a>}, html
  end

  test "returns html_safe buffer" do
    assert markdown("hello").html_safe?
  end
end
