require "test_helper"

class Llm::AnthropicDocumentsTest < ActiveSupport::TestCase
  test "supports_documents? returns true" do
    assert Llm::Anthropic.new.supports_documents?
  end

  test "builds correct request body with PDF documents" do
    adapter = Llm::Anthropic.new
    pdf_data = Base64.strict_encode64("%PDF-1.4 test")
    content = adapter.send(:build_user_content, "analyze this", [ pdf_data ])

    assert_equal 2, content.length
    assert_equal "document", content[0][:type]
    assert_equal "base64", content[0][:source][:type]
    assert_equal "application/pdf", content[0][:source][:media_type]
    assert_equal "text", content[1][:type]
  end

  test "builds text-only content without documents" do
    adapter = Llm::Anthropic.new
    content = adapter.send(:build_user_content, "analyze this", [])

    assert_equal 1, content.length
    assert_equal "text", content[0][:type]
  end
end
