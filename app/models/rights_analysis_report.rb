class RightsAnalysisReport < ApplicationRecord
  belongs_to :user
  belongs_to :property

  enum :verdict, { safe: 0, caution: 1, danger: 2 }

  validates :user_id, uniqueness: { scope: :property_id }
  validates :analyzed_at, presence: true

  def effective_tenants
    parsed_data&.dig("calculated", "tenants") || parsed_data&.dig("tenants") || []
  end

  def effective_rights_timeline
    parsed_data&.dig("llm_raw", "rights_timeline") || parsed_data&.dig("rights_timeline") || []
  end

  def discrepancies
    parsed_data&.dig("discrepancies") || []
  end

  def unevaluated_rights
    parsed_data&.dig("calculated", "unevaluated_rights") || []
  end

  def rights_disclaimer
    parsed_data&.dig("calculated", "disclaimer")
  end

  def checklist_reference_codes
    data = parsed_data
    return [] if data.blank?
    data.dig("llm_raw", "checklist_references") || data.dig("checklist_references") || []
  end

  def parsed_data
    return nil if report_data.nil?
    return report_data if report_data.is_a?(Hash)
    JSON.parse(report_data)
  rescue JSON::ParserError
    {}
  end

  # Persists user-supplied corrections to a single tenant entry.
  # NOTE: Does not re-run RightsValidator — derived fields (opposing_power,
  # priority_rank) retain their AI-computed values and may be stale after edit.
  # The next AI analysis run will recompute them. Rows edited here are flagged
  # with "user_edited": true so reviewers know the AI value was overridden.
  def update_tenant!(index, attrs)
    data = parsed_data&.deep_dup || {}
    tenants = data.dig("calculated", "tenants") || data["tenants"] || []
    raise IndexError, "tenant index #{index} out of bounds (size #{tenants.size})" if index >= tenants.size

    tenants[index] = tenants[index].merge(
      "deposit"         => attrs[:deposit].present? ? Integer(attrs[:deposit]) : tenants[index]["deposit"],
      "move_in_date"    => attrs[:move_in_date].presence || tenants[index]["move_in_date"],
      "confirmed_date"  => attrs[:confirmed_date].presence || tenants[index]["confirmed_date"],
      "user_edited"     => true
    )

    if data.dig("calculated", "tenants")
      data["calculated"]["tenants"] = tenants
    else
      data["tenants"] = tenants
    end

    update!(report_data: data)
  end
end
