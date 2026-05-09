class UsersController < ApplicationController
  def toggle_beginner_mode
    current_user.update!(beginner_mode: !current_user.beginner_mode?)
    redirect_back(fallback_location: root_path)
  end
end
