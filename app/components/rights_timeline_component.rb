class RightsTimelineComponent < ViewComponent::Base
  def initialize(report:)
    @report = report
    @rights = report.effective_rights_timeline.sort_by { |r| r["date"].to_s }
    @tenants = report.effective_tenants
  end

  private

  def base_right_date
    @report.base_right_date&.to_s
  end

  def all_entries
    entries = @rights.map do |right|
      {
        date: right["date"],
        type: right["type"],
        holder: right["holder"],
        amount: right["amount"],
        amount_type: right["amount_type"].presence,
        extinguished: right["extinguished_on_sale"],
        is_base: right["date"] == base_right_date,
        kind: :right
      }
    end

    @tenants.select { |t| t["opposing_power"] }.each do |tenant|
      entries << {
        date: tenant["move_in_date"],
        type: "임차인 전입",
        holder: tenant["name"],
        amount: tenant["deposit"],
        amount_type: nil,
        extinguished: false,
        is_base: false,
        kind: :tenant
      }
    end

    entries.sort_by { |e| e[:date].to_s }
  end

  def has_data?
    @rights.any? || @tenants.any?
  end

  def format_amount(amount)
    return "—" if amount.nil?
    amount.to_fs(:delimited) + "원"
  end

  def amount_type_hint(amount_type)
    AmountTypeHints.for(amount_type)
  end
end
