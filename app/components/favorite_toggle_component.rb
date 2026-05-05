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

  def button_classes
    base = "inline-flex items-center justify-center p-2 rounded-md transition-colors duration-150"
    color = favorited? ? "text-amber-400 hover:text-amber-500" : "text-slate-400 hover:text-amber-400"
    "#{base} #{color}"
  end
end
