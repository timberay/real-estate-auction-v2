class ManualsController < ApplicationController
  around_action :use_ko_locale

  def show
    @progress = Manuals::Progress.for(current_user)
  end

  private

  def use_ko_locale(&)
    I18n.with_locale(:ko, &)
  end
end
