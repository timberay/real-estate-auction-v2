module Properties
  class PhotosController < ApplicationController
    include PropertyScopable

    before_action :set_user_property

    def create
      @user_property.photos.attach(params[:photo])

      if @user_property.valid?
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "user-property-photos",
              partial: "properties/photos/photos",
              locals: { user_property: @user_property, property: @property }
            )
          end
          format.html { redirect_to property_path(@property) }
        end
      else
        @user_property.photos.last&.purge
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "user-property-photos",
              partial: "properties/photos/photos",
              locals: {
                user_property: @user_property,
                property: @property,
                errors: @user_property.errors[:photos].join(", ")
              }
            ), status: :unprocessable_entity
          end
          format.html { redirect_to property_path(@property), alert: @user_property.errors[:photos].join(", ") }
        end
      end
    end

    def destroy
      attachment = @user_property.photos.find_by(id: params[:id])
      return render plain: "Not Found", status: :not_found unless attachment

      attachment.purge

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "user-property-photos",
            partial: "properties/photos/photos",
            locals: { user_property: @user_property.reload, property: @property }
          )
        end
        format.html { redirect_to property_path(@property) }
      end
    end
  end
end
