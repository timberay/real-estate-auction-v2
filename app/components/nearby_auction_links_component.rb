# frozen_string_literal: true

# T1.4(a)-lite — external link to 매각가율 statistics on 법원경매정보.
# We considered building an in-house AuctionResult model + scraper, but
# dong-level coverage at a meaningful sample size (~80-150 dongs nationwide)
# made the ROI weak versus pointing users to the authoritative source.
# See `docs/superpowers/plans/2026-05-14-master-todo.md` T1.4(a).
class NearbyAuctionLinksComponent < ViewComponent::Base
  COURT_SEARCH_URL = "https://www.courtauction.go.kr/pgj/index.on?w2xPath=/pgj/ui/pgj100/PGJ151F00.xml"

  def initialize(property:)
    @property = property
  end

  def region_label
    [ @property.sido, @property.sigungu, @property.dong ].reject(&:blank?).join(" ")
  end
end
