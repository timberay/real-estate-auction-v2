class HomeController < ApplicationController
  skip_before_action :ensure_user

  def index
    if current_user&.budget_setting&.completed?
      redirect_to properties_path
    else
      redirect_to start_onboarding_url
    end
  end
end
