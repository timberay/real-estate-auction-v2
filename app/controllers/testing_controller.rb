# Test-only controller for seeding cookies that integration tests cannot set
# directly. Routes are mapped only when Rails.env.test? (see config/routes.rb);
# the before_action below is a defense-in-depth guard against env misconfig
# where the route guard might be bypassed (e.g. RAILS_ENV unexpectedly set).
class TestingController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :ensure_user
  before_action :ensure_test_env

  def set_remember_cookie
    cookies.permanent.signed[:remember_token] = params[:user_id].to_i
    render plain: "ok"
  end

  private

  def ensure_test_env
    return if Rails.env.test?
    raise "TestingController is test-only (env=#{Rails.env})"
  end
end
