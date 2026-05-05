# frozen_string_literal: true

require "test_helper"

class FavoriteToggleComponentTest < ViewComponent::TestCase
  test "renders outline star + 즐겨찾기 추가 label when not favorited" do
    up = user_properties(:guest_safe_apartment) # favorite: false
    render_inline(FavoriteToggleComponent.new(user_property: up))

    assert_selector "button[aria-label='즐겨찾기 추가']"
    assert_selector "button[aria-pressed='false']"
    assert_selector "svg[data-favorite-state='off']"
  end

  test "renders solid star + 즐겨찾기 해제 label when favorited" do
    up = user_properties(:guest_favorited_villa) # favorite: true
    render_inline(FavoriteToggleComponent.new(user_property: up))

    assert_selector "button[aria-label='즐겨찾기 해제']"
    assert_selector "button[aria-pressed='true']"
    assert_selector "svg[data-favorite-state='on']"
  end

  test "wraps in dom_id for turbo replacement" do
    up = user_properties(:guest_safe_apartment)
    render_inline(FavoriteToggleComponent.new(user_property: up))

    assert_selector "##{ActionView::RecordIdentifier.dom_id(up, :favorite_toggle)}"
  end

  test "submits PATCH to toggle_favorite_property_path" do
    up = user_properties(:guest_safe_apartment)
    render_inline(FavoriteToggleComponent.new(user_property: up))

    assert_selector "form[action='#{Rails.application.routes.url_helpers.toggle_favorite_property_path(up.property)}']"
    assert_selector "input[name='_method'][value='patch']", visible: :all
  end
end
