module Properties
  class UserPropertySettingsController < ApplicationController
    include PropertyScopable

    before_action :set_user_property

    def edit
    end

    def update
    end

    private

    def user_property_params
      params.require(:user_property).permit(:notes, :inspection_visited_on)
    end
  end
end
