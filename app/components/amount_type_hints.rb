module AmountTypeHints
  module_function

  # Single source of truth for amount_type tooltip hints shown on rights timelines.
  # Returns the hint string for an amount_type, or nil if no hint is defined.
  HINTS = {
    "채권최고액" => "※ 실제 채권액과 다를 수 있음 (보통 110~120%)"
  }.freeze

  def for(amount_type)
    HINTS[amount_type]
  end
end
