require "test_helper"

class Properties::PhotosControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url
    @user = inherit_fixture_guest_ownership

    @property = properties(:safe_apartment)
    @user_property = UserProperty.find_by!(user: @user, property: @property)
  end

  def png_upload
    fixture_file_upload(Rails.root.join("test/fixtures/files/test_photo.png"), "image/png")
  end

  def text_upload
    fixture_file_upload(Rails.root.join("test/fixtures/files/test_doc.txt"), "text/plain")
  end

  # Auth
  test "unauthenticated POST create redirects to login" do
    delete auth_logout_path
    post property_photos_path(@property), params: { photo: png_upload }
    assert_redirected_to auth_login_path
  end

  test "unauthenticated DELETE destroy redirects to login" do
    delete auth_logout_path
    delete property_photo_path(@property, 1)
    assert_redirected_to auth_login_path
  end

  # Authorization
  test "non-owner POST create returns 404" do
    other_property = properties(:risky_villa)
    UserProperty.where(user: @user, property: other_property).destroy_all
    post property_photos_path(other_property), params: { photo: png_upload }
    assert_response :not_found
  end

  # Happy path — create
  test "POST create with image attaches photo" do
    assert_difference -> { @user_property.photos.count }, 1 do
      post property_photos_path(@property),
        params: { photo: png_upload },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success
  end

  # Validation failure — non-image
  test "POST create with non-image returns unprocessable_entity" do
    assert_no_difference -> { @user_property.photos.count } do
      post property_photos_path(@property),
        params: { photo: text_upload },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :unprocessable_entity
  end

  # Happy path — destroy
  test "DELETE destroy purges the photo" do
    @user_property.photos.attach(
      io: StringIO.new("fake img"),
      filename: "photo.png",
      content_type: "image/png"
    )
    attachment = @user_property.photos.last

    assert_difference -> { @user_property.photos.count }, -1 do
      delete property_photo_path(@property, attachment.id),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success
  end

  test "DELETE destroy with unknown id returns 404" do
    delete property_photo_path(@property, 999_999),
      headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :not_found
  end
end
