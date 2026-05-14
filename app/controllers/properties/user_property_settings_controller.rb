module Properties
  class UserPropertySettingsController < ApplicationController
    include PropertyScopable

    before_action :set_user_property

    def edit
    end

    def update
      @user_property.update!(user_property_params)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "user-property-notes-edit",
            partial: "properties/user_property_settings/notes_display",
            locals: { user_property: @user_property, property: @property }
          )
        end
        format.html { redirect_to property_path(@property) }
      end
    end

    private

    def user_property_params
      params.require(:user_property).permit(:notes, :inspection_visited_on, :payment_completed_on, :deposit_rate)
    end
  end
end
