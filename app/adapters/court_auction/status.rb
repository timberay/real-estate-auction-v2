module CourtAuction
  module Status
    IN_PROGRESS = "진행중".freeze
    CLOSED = "종결".freeze

    # API uses Y/N to flag whether a property is still actively up for bid.
    PROPERTY_ACTIVE_FLAG = "Y".freeze

    # Case progression code: codes starting with "0002" are in-progress.
    PROGRESS_CODE_PREFIX = "0002".freeze

    # Auction round result code: "002" indicates a failed bid.
    FAILED_BID_RESULT_CODE = "002".freeze

    module_function

    def from_property_flag(flag)
      flag == PROPERTY_ACTIVE_FLAG ? IN_PROGRESS : CLOSED
    end

    def from_progress_code(code)
      code&.start_with?(PROGRESS_CODE_PREFIX) ? IN_PROGRESS : CLOSED
    end

    def failed_bid?(result_code)
      result_code == FAILED_BID_RESULT_CODE
    end
  end
end
