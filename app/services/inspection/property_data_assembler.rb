module Inspection
  class PropertyDataAssembler
    def self.call(property)
      new(property).call
    end

    def initialize(property)
      @property = property
      @property.sale_detail # eager load
      @property.appraisal_points.load
      @property.land_details.load
      @property.auction_schedules.load
    end

    def call
      sections = [
        basic_info_section,
        sale_detail_section,
        appraisal_section,
        land_section,
        auction_section,
        raw_data_section
      ]
      sections.join("\n\n")
    end

    private

    def basic_info_section
      p = @property
      <<~TEXT
        [물건 기본 정보]
        사건번호: #{p.case_number}
        물건종류: #{p.property_type}
        소재지: #{p.address}
        감정가: #{format_price(p.appraisal_price)}
        최저입찰가: #{format_price(p.min_bid_price)}
        상태: #{val(p.status)}
        유찰횟수: #{p.failed_bid_count}회
        조회수: #{p.view_count}회
        사건유형: #{val(p.case_type)}
        청구금액: #{format_price(p.claim_amount)}
        건물명: #{val(p.building_name)}
        건물상세: #{val(p.building_detail)}
        건물구조: #{val(p.building_structure)}
        전용면적: #{p.exclusive_area ? "#{p.exclusive_area}㎡" : "(정보 없음)"}
        토지구분: #{val(p.land_category)}
        비고: #{val(p.remarks)}
        특별매각조건코드: #{val(p.special_conditions_code)}
        물건수: #{p.property_count}
      TEXT
    end

    def sale_detail_section
      sd = @property.sale_detail
      return "[매각물건명세서]\n(상세 데이터 미수집)" unless sd

      <<~TEXT
        [매각물건명세서]
        소멸되지않는권리: #{val(sd.non_extinguished_rights)}
        물건명세비고: #{val(sd.specification_remarks)}
        매각물건비고: #{val(sd.goods_remarks)}
        법정지상권: #{val(sd.superficies_details)}
        선순위저당: #{val(sd.senior_mortgage_basis)}
        지분내역: #{val(sd.share_description)}
        배당요구종기: #{sd.dividend_demand_deadline || "(정보 없음)"}
      TEXT
    end

    def appraisal_section
      points = @property.appraisal_points
      return "[감정평가서 주요사항]\n(정보 없음)" if points.empty?

      lines = points.map { |ap| "- #{ap.content}" }
      "[감정평가서 주요사항]\n#{lines.join("\n")}"
    end

    def land_section
      details = @property.land_details
      return "[토지 내역]\n(정보 없음)" if details.empty?

      lines = details.map { |ld| "- #{ld.land_type} #{ld.address} #{ld.land_category} #{ld.land_area} #{ld.share_ratio}" }
      "[토지 내역]\n#{lines.join("\n")}"
    end

    def auction_section
      schedules = @property.auction_schedules.order(:schedule_date)
      return "[경매 일정]\n(정보 없음)" if schedules.empty?

      lines = schedules.map do |s|
        "- #{s.schedule_date} #{s.schedule_type} 최저가=#{format_price(s.min_price)} 결과=#{val(s.result_code)}"
      end
      "[경매 일정]\n#{lines.join("\n")}"
    end

    def raw_data_section
      data = @property.raw_data
      return "[원시 데이터 (raw_data)]\n(정보 없음)" if data.blank?

      "[원시 데이터 (raw_data)]\n#{JSON.pretty_generate(data)}"
    end

    def val(v)
      v.present? ? v : "(정보 없음)"
    end

    def format_price(amount)
      return "(정보 없음)" if amount.nil? || amount.zero?
      ActiveSupport::NumberHelper.number_to_delimited(amount) + "원"
    end
  end
end
