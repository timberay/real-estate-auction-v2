module Properties
  class PhotosController < ApplicationController
    include PropertyScopable

    before_action :set_user_property

    def create
    end

    def destroy
    end
  end
end
