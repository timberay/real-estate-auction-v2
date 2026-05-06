class CspReportsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create
  skip_before_action :ensure_user, only: :create
  skip_before_action :capture_return_to_url, only: :create
  skip_before_action :touch_last_seen, only: :create

  def create
    Rails.logger.tagged("csp.violation") do
      Rails.logger.warn(request.raw_post.presence || "<empty>")
    end
    head :no_content
  end
end
