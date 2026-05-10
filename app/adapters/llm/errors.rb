module Llm
  module Errors
    class Error < StandardError; end

    # Raised when an LLM provider truncates its response because it hit the
    # configured max_tokens budget. Letting this bubble up surfaces the real
    # cause (incomplete output) instead of a confusing JSON parse failure.
    class ResponseTruncated < Error; end
  end
end
