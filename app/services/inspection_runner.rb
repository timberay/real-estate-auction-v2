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
    "rights-002" => ->(p) {
      text = p.sale_detail&.non_extinguished_rights
      has_risk = if p.sale_detail.nil?
        false
      else
        text.present?
      end
      {
        has_risk: has_risk,
        evidence: {
          source_label: "매각물건명세서",
          fields: [{ label: "소멸되지 않는 권리", value: text.present? ? text : "없음" }]
        }
      }
    },

    # rights-011: 유치권·법정지상권 기재
    "rights-011" => ->(p) {
      combined = [
        p.remarks,
        p.sale_detail&.specification_remarks,
        p.sale_detail&.goods_remarks,
        p.sale_detail&.superficies_details
      ].compact.join("\n")
      found = combined.present? && (combined.match?(LIEN_PATTERN) || combined.match?(SUPERFICIES_PATTERN))
      {
        has_risk: found,
        evidence: {
          source_label: "비고, 물건명세서, 현황조사서",
          keywords: { searched: ["유치권", "법정지상권"], found: found }
        }
      }
    },

    # property-002: 벽체 구분·불법 구조변경
    "property-002" => ->(p) {
      combined = [
        p.remarks,
        p.sale_detail&.specification_remarks,
        p.sale_detail&.goods_remarks
      ].compact.join("\n")
      found = combined.present? && combined.match?(WALL_PATTERN)
      {
        has_risk: found ? true : false,
        evidence: {
          source_label: "비고, 물건명세서, 현황조사서",
          keywords: { searched: ["벽체", "구조변경", "불법증축", "불법개축"], found: found ? true : false }
        }
      }
    },

    # rights-019: 토지·건물 일체 매각
    "rights-019" => ->(p) {
      return nil if p.property_type != "아파트" && p.land_category.nil?
      has_risk = if p.property_type == "아파트"
        false
      else
        p.land_category != "전유"
      end
      fields = [{ label: "물건종류", value: p.property_type }]
      fields << { label: "토지구분", value: p.land_category } if p.land_category.present?
      {
        has_risk: has_risk,
        evidence: {
          source_label: "법원경매 물건정보",
          fields: fields
        }
      }
    },

    # rights-020: 유치권 신고
    "rights-020" => ->(p) {
      combined = [
        p.remarks,
        p.sale_detail&.specification_remarks,
        p.sale_detail&.goods_remarks
      ].compact.join("\n")
      found = combined.present? && combined.match?(LIEN_PATTERN)
      {
        has_risk: found ? true : false,
        evidence: {
          source_label: "비고, 물건명세서, 현황조사서",
          keywords: { searched: ["유치권"], found: found ? true : false }
        }
      }
    },

    # property-006: 물건 종류 아파트 여부
    "property-006" => ->(p) {
      {
        has_risk: p.property_type != "아파트",
        evidence: {
          source_label: "법원경매 물건정보",
          fields: [{ label: "물건종류", value: p.property_type }]
        }
      }
    },

    # resale-003: 지상층 위치
    "resale-003" => ->(p) {
      floor = p.building_detail
      return nil if floor.blank?
      {
        has_risk: floor.match?(/지하|반지하/) && !floor.match?(/지상/),
        evidence: {
          source_label: "법원경매 물건정보",
          fields: [{ label: "층 정보", value: floor }]
        }
      }
    },

    # property-001: 비지분 물건
    "property-001" => ->(p) {
      return nil if p.sale_detail.nil?
      share = p.sale_detail.share_description
      {
        has_risk: share.present?,
        evidence: {
          source_label: "매각물건명세서",
          fields: [{ label: "지분 내역", value: share.present? ? share : "없음" }]
        }
      }
    },

    # tax-006: 전용면적 85㎡ 미만
    "tax-006" => ->(p) {
      area = p.exclusive_area
      return nil if area.nil? || area.zero?
      {
        has_risk: area >= 85,
        evidence: {
          source_label: "법원경매 물건정보",
          fields: [{ label: "전용면적", value: "#{area}㎡" }]
        }
      }
    },

    # market-012: 조회수 500회 미만
    "market-012" => ->(p) {
      count = p.view_count || 0
      {
        has_risk: count >= 500,
        evidence: {
          source_label: "법원경매 물건정보",
          fields: [{ label: "조회수", value: "#{count}회" }]
        }
      }
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
      found = all_text.match?(USE_APPROVAL_PATTERN)
      return nil unless found
      {
        has_risk: true,
        evidence: {
          source_label: "물건명세서, 감정평가서",
          keywords: { searched: ["무허가", "미등기", "사용승인 미", "허가 미취득"], found: true }
        }
      }
    },

    # inspect-001: 감정평가서 특이사항 (keyword detection)
    "inspect-001" => ->(p) {
      text = p.appraisal_points.map(&:content).compact.join("\n")
      return nil if text.blank?
      found = text.match?(APPRAISAL_RISK_PATTERN)
      return nil unless found
      {
        has_risk: true,
        evidence: {
          source_label: "감정평가서",
          keywords: { searched: ["불법증축", "무허가", "환경오염", "면적불일치", "균열", "누수", "침수"], found: true }
        }
      }
    },

    # inspect-004: 오피스텔 주거/업무 용도
    "inspect-004" => ->(p) {
      nil
    },

    # market-006: 단지형 건물 여부
    "market-006" => ->(p) {
      if p.property_type == "아파트" && p.building_name.present?
        {
          has_risk: false,
          evidence: {
            source_label: "법원경매 물건정보",
            fields: [
              { label: "물건종류", value: p.property_type },
              { label: "건물명", value: p.building_name }
            ]
          }
        }
      else
        nil
      end
    },

    # rights-021: 전세사기 피해자 우선매수권
    "rights-021" => ->(p) {
      combined = [
        p.special_conditions_code,
        p.remarks,
        p.sale_detail&.specification_remarks
      ].compact.join("\n")
      return nil if combined.blank?
      found = combined.match?(FRAUD_PATTERN)
      return nil unless found
      {
        has_risk: true,
        evidence: {
          source_label: "특별매각조건, 비고, 물건명세서",
          keywords: { searched: ["우선매수", "전세사기", "특별법"], found: true }
        }
      }
    },

    # bidding-001: 경매 진행 상태 확인
    "bidding-001" => ->(p) {
      return nil if p.status.blank?
      return nil if p.status == "진행중"
      {
        has_risk: true,
        evidence: {
          source_label: "법원경매 물건정보",
          fields: [{ label: "진행상태", value: p.status }]
        }
      }
    },

    # bidding-003: 입찰 보증금 준비
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
        unless user_manually_answered?(result)
          result.assign_attributes(source_type: nil, has_risk: nil, evidence: nil)
        end
      else
        detected = begin
          rule.call(@property)
        rescue
          nil
        end
        if detected.nil?
          unless user_manually_answered?(result)
            result.assign_attributes(source_type: nil, has_risk: nil, evidence: nil)
          end
        elsif detected.is_a?(Hash)
          result.assign_attributes(
            source_type: "auto",
            has_risk: detected[:has_risk],
            evidence: detected[:evidence]
          )
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
