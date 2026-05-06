# Test-only controller for seeding cookies that integration tests cannot set directly.
class TestingController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :ensure_user

  def set_remember_cookie
    cookies.permanent.signed[:remember_token] = params[:user_id].to_i
    render plain: "ok"
  end
end
