# frozen_string_literal: true

module Manuals
  ProgressResult = Data.define(:steps, :current_step, :continue_cta) do
    def fetch_step(key)
      steps.find { |s| s.key == key }
    end
  end
end
