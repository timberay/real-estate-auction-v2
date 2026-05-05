# frozen_string_literal: true

class FavoriteToggleComponent < ViewComponent::Base
  def initialize(user_property:)
    @user_property = user_property
  end

  private

  def favorited?
    @user_property.favorite
  end

  def aria_label
    favorited? ? "즐겨찾기 해제" : "즐겨찾기 추가"
  end

  def wrapper_id
    helpers.dom_id(@user_property, :favorite_toggle)
  end
end
