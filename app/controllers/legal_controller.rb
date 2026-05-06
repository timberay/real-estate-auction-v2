class LegalController < ApplicationController
  skip_before_action :require_authenticated_user

  around_action :use_ko_locale

  def terms; end
  def privacy; end

  private

  def use_ko_locale(&)
    I18n.with_locale(:ko, &)
  end
end
