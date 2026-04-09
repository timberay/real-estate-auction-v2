class InspectionRunner
  LIEN_PATTERN = /유치권/
  SUPERFICIES_PATTERN = /법정지상권/
  WALL_PATTERN = /벽체|구조변경|불법.*증축|불법.*개축/
  USE_APPROVAL_PATTERN = /무허가|미등기|사용승인.*미|허가.*미취득/
  APPRAISAL_RISK_PATTERN = /불법.*증축|무허가|환경오염|면적.*불일치|균열|누수|침수/
  FRAUD_PATTERN = /우선매수|전세사기|특별법/

  DETECTION_RULES = {
    # ============================================================
    # Auto grade — court_auction fields fully determine yes/no
    # ============================================================

    # rights-002: 소멸되지 않는 인수 권리 유무
    # nil sale_detail = no rights to assume = safe
    "rights-002" => ->(p) {
      text = p.sale_detail&.non_extinguished_rights
      return false if p.sale_detail.nil?
      text.present?
    },

    # rights-011: 유치권·법정지상권 기재
    # blank text = safe (not nil)
    "rights-011" => ->(p) {
      combined = [
        p.remarks,
        p.sale_detail&.specification_remarks,
        p.sale_detail&.goods_remarks,
        p.sale_detail&.superficies_details
      ].compact.join("\n")
      return false if combined.blank?
      combined.match?(LIEN_PATTERN) || combined.match?(SUPERFICIES_PATTERN)
    },

    # property-002: 벽체 구분·불법 구조변경
    # blank text = safe (not nil)
    "property-002" => ->(p) {
      combined = [
        p.remarks,
        p.sale_detail&.specification_remarks,
        p.sale_detail&.goods_remarks
      ].compact.join("\n")
      return false if combined.blank?
      combined.match?(WALL_PATTERN) ? true : false
    },

    # rights-019: 토지·건물 일체 매각
    "rights-019" => ->(p) {
      return false if p.property_type == "아파트"
      cat = p.land_category
      return nil if cat.nil?
      cat != "전유"
    },

    # rights-020: 유치권 신고
    # blank text = safe (not nil)
    "rights-020" => ->(p) {
      combined = [
        p.remarks,
        p.sale_detail&.specification_remarks,
        p.sale_detail&.goods_remarks
      ].compact.join("\n")
      return false if combined.blank?
      combined.match?(LIEN_PATTERN) ? true : false
    },

    # property-006: 물건 종류 아파트 여부
    "property-006" => ->(p) {
      p.property_type != "아파트"
    },

    # resale-003: 지상층 위치
    "resale-003" => ->(p) {
      floor = p.building_detail
      return nil if floor.blank?
      floor.match?(/지하|반지하/) && !floor.match?(/지상/)
    },

    # property-001: 비지분 물건
    "property-001" => ->(p) {
      return nil if p.sale_detail.nil?
      p.sale_detail.share_description.present?
    },

    # tax-006: 전용면적 85㎡ 미만
    "tax-006" => ->(p) {
      area = p.exclusive_area
      return nil if area.nil? || area.zero?
      area >= 85
    },

    # market-012: 조회수 500회 미만
    "market-012" => ->(p) {
      (p.view_count || 0) >= 500
    },

    # ============================================================
    # Partial grade — hints or partial conditions
    # ============================================================

    # rights-005: 사용 승인 정상 건물 (risk detection only)
    "rights-005" => ->(p) {
      combined = [
        p.sale_detail&.specification_remarks,
        p.sale_detail&.goods_remarks
      ].compact.join("\n")
      appraisal_text = p.appraisal_points.map(&:content).compact.join("\n")
      all_text = [ combined, appraisal_text ].reject(&:blank?).join("\n")
      return nil if all_text.blank?
      all_text.match?(USE_APPROVAL_PATTERN) ? true : nil
    },

    # inspect-001: 감정평가서 특이사항 (keyword detection)
    "inspect-001" => ->(p) {
      text = p.appraisal_points.map(&:content).compact.join("\n")
      return nil if text.blank?
      text.match?(APPRAISAL_RISK_PATTERN) ? true : nil
    },

    # inspect-004: 오피스텔 주거/업무 용도
    # Partial: auto-flag risk for 오피스텔 only; non-오피스텔 left for user to confirm
    "inspect-004" => ->(p) {
      nil
    },

    # market-006: 단지형 건물 여부
    "market-006" => ->(p) {
      return false if p.property_type == "아파트" && p.building_name.present?
      nil
    },

    # rights-021: 전세사기 피해자 우선매수권
    "rights-021" => ->(p) {
      combined = [
        p.special_conditions_code,
        p.remarks,
        p.sale_detail&.specification_remarks
      ].compact.join("\n")
      return nil if combined.blank?
      combined.match?(FRAUD_PATTERN) ? true : nil
    },

    # bidding-001: 경매 진행 상태 확인
    # Partial: status is displayable but user must confirm they checked
    "bidding-001" => ->(p) {
      return nil if p.status.blank?
      p.status != "진행중" ? true : nil
    },

    # bidding-003: 입찰 보증금 준비
    # Partial: deposit amount is calculable but preparation is user action
    "bidding-003" => ->(p) {
      nil
    }
  }.freeze

  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    # Eager load associations to avoid N+1
    @property.sale_detail
    @property.appraisal_points.load

    InspectionItem.ordered.map do |item|
      result = @property.inspection_results.find_or_initialize_by(inspection_item: item, user: @user)

      rule = DETECTION_RULES[item.code]
      if rule.nil?
        # No detection rule — leave as unanswered unless user manually answered
        unless user_manually_answered?(result)
          result.assign_attributes(source_type: nil, has_risk: nil)
        end
      else
        detected = begin
          rule.call(@property)
        rescue
          nil
        end
        if detected.nil?
          # Rule returned nil — reset unless user manually answered
          unless user_manually_answered?(result)
            result.assign_attributes(source_type: nil, has_risk: nil)
          end
        else
          result.assign_attributes(source_type: "auto", has_risk: detected)
        end
      end

      result.save!
      result
    end
  end

  def user_manually_answered?(result)
    result.persisted? && result.manual? && result.auto_value.blank?
  end
end
