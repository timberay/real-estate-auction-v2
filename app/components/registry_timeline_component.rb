class RegistryTimelineComponent < ViewComponent::Base
  def initialize(report:, property: nil)
    @report = report
    @property = property
    @timeline = report.effective_rights_timeline
    @tenants = report.effective_tenants
    @checklist_refs = ChecklistCodeMapping.build_checklist_refs(report.checklist_reference_codes)
  end

  private

  def sorted_entries
    rights = @timeline.map { |e| { kind: :right, date: e["date"], payload: e } }
    tenants = @tenants.each_with_index.map { |t, i| { kind: :tenant, date: t["move_in_date"], payload: t, index: i } }
    (rights + tenants).sort_by { |e| e[:date].to_s }
  end

  def base_right_date
    @report.base_right_date
  end

  def format_amount(amount)
    return "—" if amount.nil?
    amount.to_fs(:delimited) + "원"
  end

  def amount_type_hint(amount_type)
    AmountTypeHints.for(amount_type)
  end
end
