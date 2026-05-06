module CourtAuction
  # Single source of truth for the court auction service URLs. Allow ENV
  # override (COURT_AUCTION_HOST) so staging/canary deployments can swap
  # to a mirror without code change.
  module Endpoints
    DEFAULT_HOST = "https://www.courtauction.go.kr"
    BASE_PATH = "/pgj/"

    module_function

    def host
      ENV.fetch("COURT_AUCTION_HOST", DEFAULT_HOST)
    end

    # Faraday connection root, e.g. "https://www.courtauction.go.kr/pgj/"
    def base_url
      "#{host}#{BASE_PATH}"
    end

    # Returns the WebSquare entry URL for a given screen path,
    # e.g. screen_url("PGJ151F00") → ".../index.on?w2xPath=/pgj/ui/pgj100/PGJ151F00.xml"
    def screen_url(screen_id)
      "#{host}#{BASE_PATH}index.on?w2xPath=/pgj/ui/pgj100/#{screen_id}.xml"
    end

    # Aliases for the screens this app uses.
    CRITERIA_SEARCH_SCREEN = "PGJ151F00".freeze
    CASE_SEARCH_SCREEN = "PGJ159M00".freeze

    def criteria_search_referer
      screen_url(CRITERIA_SEARCH_SCREEN)
    end

    def case_search_referer
      screen_url(CASE_SEARCH_SCREEN)
    end
  end
end
