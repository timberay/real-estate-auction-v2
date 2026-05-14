class Property < ApplicationRecord
  has_many :auction_schedules, dependent: :destroy
  # Eager-loadable single-record association for the next upcoming schedule.
  # Lambda re-evaluates Date.current each request so preload stays fresh.
  has_one :next_auction_schedule,
          -> { where("schedule_date >= ?", Date.current).order(:schedule_date) },
          class_name: "AuctionSchedule"

  has_many :user_properties, dependent: :destroy
  has_many :users, through: :user_properties
  has_many :inspection_results, dependent: :destroy
  has_many :inspection_items, through: :inspection_results
  has_many :rights_analysis_reports, dependent: :destroy
  has_many :llm_analysis_logs, dependent: :destroy
  has_many :eviction_simulations, dependent: :destroy

  has_many_attached :documents

  validates :case_number, presence: true, uniqueness: true
  validate :documents_must_be_pdf

  # T1.4(b) — 한국 법원경매 표준 저감률 (8할). 일부 법원은 7할이지만
  # 가장 보편적인 8할로 간소화. 향후 법원별 차등이 필요하면 별도 분기.
  NEXT_ROUND_REDUCTION_RATE = 0.80

  # 유찰 시 다음 회차 최저매각가. 만원(10,000원) 단위로 절사하여
  # 법원 공고 표시 단위와 맞춤.
  def next_round_min_bid_price
    return nil if min_bid_price.nil? || min_bid_price.zero?
    reduced = (min_bid_price * NEXT_ROUND_REDUCTION_RATE).floor
    (reduced / 10_000) * 10_000
  end

  def analyzed?
    inspection_results.exists?
  end

  def needs_manual_input?
    inspection_results.where(has_risk: nil).exists?
  end

  # T3.1 — categorize property_type (free-text from court data) into a
  # coarse usage bucket. The acquisition/transfer tax matrices in this app
  # are seeded for 주거(residential) types; non-residential properties
  # (오피스텔/상가/토지) need the user to verify externally because the
  # tax brackets differ materially (e.g. CGT is not subject to the 1세대
  # 1주택 비과세, acquisition tax may be flat 4.6%). When property_type is
  # blank we default to :residential — the safer assumption for the most
  # common case (아파트/빌라 dominate the dataset).
  def usage_category
    return :residential if property_type.blank?
    case property_type
    when /오피스텔/
      :officetel
    when /상가|근린|시장/
      :commercial
    when /토지|대지|임야|전\b|답\b|과수원|목장|공장용지|잡종지/
      :land
    when /아파트|빌라|다세대|연립|단독|주택|도시형생활주택/
      :residential
    else
      :unknown
    end
  end

  def residential?
    usage_category == :residential
  end

  # D3b — pull fresh data from the court auction API into this Property.
  # CaseSearchService#persist is "create or no-op on existing", which is the
  # wrong semantics for a refresh, so this method explicitly rewrites
  # court-sourced columns (case_number, the identity, is preserved).
  def refresh_from_court_auction!
    raise ArgumentError, "court_code is required for refresh" if court_code.blank?

    api_data = GovernmentCourtAuctionAdapter.new.search_case(court_code: court_code, case_number: case_number)
    parsed = api_data && CourtAuction::ResponseParser.new.parse_case_search(api_data: api_data)

    if parsed.nil?
      raise DataProvider::DataNotFoundError, "Case #{case_number} not found at court #{court_code}"
    end

    update!(parsed.except(:case_number))
  end

  private

  def documents_must_be_pdf
    documents.each do |doc|
      unless doc.content_type == "application/pdf"
        errors.add(:documents, "PDF 파일만 업로드할 수 있습니다.")
      end
    end
  end
end
