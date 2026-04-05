class HomeController < ApplicationController
  def index
    if current_user.budget_setting&.completed?
      render :index
    else
      redirect_to start_onboarding_url
    end
  end
end
