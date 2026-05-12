# Base class for all `/admin/*` controllers. Builds on
# ApplicationController's `require_authenticated_user` filter and adds an
# `admin?` gate that returns 404 (rather than 403) so the URL space stays
# invisible to non-admins.
module Admin
  class BaseController < ApplicationController
    before_action :require_admin

    private

    def require_admin
      return if current_user&.admin?
      raise ActionController::RoutingError, "Not Found"
    end
  end
end
