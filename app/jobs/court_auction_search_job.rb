class CourtAuctionSearchJob < ApplicationJob
  include CourtAuctionErrorMessages

  queue_as :default
  limits_concurrency to: 1, key: "court_browser"

  discard_on ActiveRecord::RecordNotFound
  discard_on ActiveJob::DeserializationError

  def perform(user_id:, address:, max_bid_price:)
    user = User.find(user_id)
    result = CourtAuctionSearchService.call(
      user: user,
      address: address,
      max_bid_price: max_bid_price
    )

    if result.error
      broadcast_error(user, result.error)
    else
      broadcast_ready(user)
    end
  end

  private

  def stream_name(user)
    "criteria_search_#{user.id}"
  end

  def broadcast_ready(user)
    user.reload
    search_results = user.search_results.order(created_at: :desc).limit(20)
    api_total_count = user.last_search_api_total_count
    over_api_limit  = api_total_count.to_i > 100
    existing_case_numbers = user.properties.pluck(:case_number).to_set
    total_pages = [ (user.search_results.count.to_f / 20).ceil, 1 ].max

    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name(user),
      target: "criteria-search-results",
      partial: "search_results/results_panel",
      locals: {
        search_results: search_results,
        search_page: 1,
        total_pages: total_pages,
        api_total_count: api_total_count,
        over_api_limit: over_api_limit,
        existing_case_numbers: existing_case_numbers
      }
    )
  end

  def broadcast_error(user, error)
    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name(user),
      target: "criteria-search-results",
      partial: "search_results/error_panel",
      locals: { message: error_message_for(error) }
    )
  end
end
