# frozen_string_literal: true

class ChecklistGroupComponent < ViewComponent::Base
  AXIS_LABELS = {
    "legal" => "법적 위험",
    "resale" => "매도 위험",
    "loan" => "대출 위험"
  }.freeze

  def initialize(axis:, results:, show_resolution: false)
    @axis = axis
    @results = results
    @show_resolution = show_resolution
  end

  private

  def axis_label
    AXIS_LABELS[@axis] || @axis
  end

  def risk_count
    @results.count { |r| r.has_risk }
  end
end
