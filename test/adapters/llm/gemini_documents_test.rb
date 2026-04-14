require "test_helper"

class Llm::GeminiDocumentsTest < ActiveSupport::TestCase
  test "supports_documents? returns true" do
    assert Llm::Gemini.new.supports_documents?
  end

  test "builds correct request parts with PDF documents" do
    adapter = Llm::Gemini.new
    pdf_data = Base64.strict_encode64("%PDF-1.4 test")
    parts = adapter.send(:build_content_parts, "analyze this", [ pdf_data ])

    assert_equal 2, parts.length
    assert_equal "application/pdf", parts[0][:inline_data][:mime_type]
    assert_equal "analyze this", parts[1][:text]
  end

  test "builds text-only parts without documents" do
    adapter = Llm::Gemini.new
    parts = adapter.send(:build_content_parts, "analyze this", [])

    assert_equal 1, parts.length
    assert_equal "analyze this", parts[0][:text]
  end
end
