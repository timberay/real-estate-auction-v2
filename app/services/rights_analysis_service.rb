class RightsAnalysisService
  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    registry_data = @property.raw_data&.dig("registry_transcript")
    check_results = @property.property_check_results.where(user: @user).includes(:checklist_item)

    # Step 1: Extract base right
    base_right = RightsAnalysis::ExtinguishmentBaseRightExtractor.call(registry_data)

    # Step 2: Determine opposing power
    tenants = RightsAnalysis::OpposingPowerDeterminer.call(registry_data, base_right)

    # Step 3: Calculate assumed amount
    assumed = RightsAnalysis::AssumedAmountCalculator.call(tenants)

    # Step 4: Detect opportunities
    opportunity = RightsAnalysis::OpportunityDetector.call(
      registry_data: registry_data, tenants: tenants, check_results: check_results
    )

    # Step 5: Build report data
    timeline = build_timeline(registry_data)
    checklist_refs = find_checklist_references(check_results)
    verdict, summary = compute_verdict(base_right, tenants, assumed, check_results)

    # Step 6: Persist
    report = RightsAnalysisReport.find_or_initialize_by(user: @user, property: @property)
    report.assign_attributes(
      base_right_type: base_right&.dig(:type),
      base_right_date: base_right&.dig(:date),
      base_right_holder: base_right&.dig(:holder),
      assumed_amount: assumed[:assumed_amount],
      total_risk_amount: assumed[:total_risk_amount],
      verdict: verdict,
      verdict_summary: summary,
      opportunity_type: opportunity[:opportunity_type],
      opportunity_reason: opportunity[:opportunity_reason],
      analyzed_at: Time.current,
      report_data: {
        registry_timeline: timeline,
        tenants: tenants,
        dividend_simulation: { expected_bid: nil, distribution: [] },
        bidder_burden: {
          assumed_amount: assumed[:assumed_amount],
          unconfirmed_risk: assumed[:total_risk_amount] - assumed[:assumed_amount],
          total_burden: assumed[:total_risk_amount],
          verdict: verdict.to_s
        },
        checklist_references: checklist_refs
      }
    )
    report.save!
    report
  end

  private

  def build_timeline(registry_data)
    return [] if registry_data.nil?

    rights = (registry_data["rights"] || []).map do |r|
      { date: r["date"], type: r["type"], holder: r["holder"], amount: r["amount"], registry_section: r["registry_section"] }
    end

    seizures = (registry_data["seizures"] || []).map do |s|
      { date: s["date"], type: s["type"], holder: s["holder"], amount: s["amount"], registry_section: "갑구" }
    end

    (rights + seizures).sort_by { |e| Date.parse(e[:date]) }
  end

  def find_checklist_references(check_results)
    relevant_codes = %w[rights-003 rights-006 rights-009 rights-011]
    check_results
      .select { |r| relevant_codes.include?(r.checklist_item.code) && r.has_risk == true }
      .map { |r| r.checklist_item.code }
  end

  def compute_verdict(base_right, tenants, assumed, check_results)
    has_lien = check_results.any? { |r| r.checklist_item.code == "rights-011" && r.has_risk == true }

    verdict = if has_lien || assumed[:assumed_amount] > 0
      :danger
    elsif assumed[:total_risk_amount] > 0
      :caution
    else
      :safe
    end

    lines = []
    if base_right && base_right[:type].present?
      lines << "말소기준권리: #{base_right[:type]} (#{base_right[:date]}, #{base_right[:holder]})"
    else
      lines << "말소기준권리: 해당 없음"
    end

    opposing = tenants.select { |t| t[:has_opposing_power] == true }
    if opposing.any?
      lines << "대항력 있는 임차인 #{opposing.size}명 — 인수 금액 #{format_amount(assumed[:assumed_amount])}"
    else
      lines << (tenants.any? ? "임차인 #{tenants.size}명 — 대항력 없음, 인수 금액 0원" : "임차인 없음")
    end

    lines << "유치권 신고 있음" if has_lien

    [ verdict, lines.join("\n") ]
  end

  def format_amount(amount)
    if amount >= 100_000_000
      "#{amount / 100_000_000}억#{amount % 100_000_000 > 0 ? " #{(amount % 100_000_000).to_fs(:delimited)}원" : "원"}"
    else
      "#{amount.to_fs(:delimited)}원"
    end
  end
end
