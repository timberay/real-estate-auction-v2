module EvictionGuide
  class F02PrefillComponent < ViewComponent::Base
    def initialize(prefill_data:, simulation:)
      @prefill_data = prefill_data || {}
      @simulation = simulation
    end

    private

    FIELD_LABELS = {
      has_opposing_tenant: "대항력 있는 임차인 존재 여부",
      is_dividend_requested: "배당요구 여부",
      has_lien: "유치권 신고 존재",
      has_gratuitous_residence_doc: "무상거주확인서 정황",
      occupant_type: "점유자 유형",
      has_small_sum_tenant: "소액임차인 여부",
      has_rights_analysis: "권리분석 완료 여부"
    }.freeze

    def fields
      @prefill_data.map do |key, value|
        {
          key: key,
          label: FIELD_LABELS[key] || key.to_s.humanize,
          value: value,
          display_value: format_value(value)
        }
      end
    end

    def format_value(value)
      case value
      when true then "있음"
      when false then "없음"
      when nil then "미확인"
      else value.to_s
      end
    end
  end
end
