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

  test "non-owner DELETE destroy returns 404" do
    other_property = properties(:risky_villa)
    other_user_property = UserProperty.find_by!(property: other_property)
    other_user_property.photos.attach(
      io: StringIO.new("fake img"),
      filename: "photo.png",
      content_type: "image/png"
    )
    photo_id = other_user_property.photos.last.id

    UserProperty.where(user: @user, property: other_property).destroy_all

    delete property_photo_path(other_property, photo_id)
    assert_response :not_found
  end

  test "T2.8: photos partial preloads blobs (no per-photo N+1 SELECT)" do
    3.times do |i|
      @user_property.photos.attach(
        io: StringIO.new("img#{i}"),
        filename: "p#{i}.png",
        content_type: "image/png"
      )
    end
    target_id = @user_property.photos.first.id

    sqls = []
    callback = lambda do |*, payload|
      next if payload[:name] == "SCHEMA"
      sqls << payload[:sql].to_s if payload[:sql].to_s =~ /"active_storage_blobs"/i
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      delete property_photo_path(@property, target_id),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    single_id_selects = sqls.count { |s| s.match?(/SELECT.+"active_storage_blobs".+WHERE.+"id"\s*=/) }
    assert single_id_selects <= 1,
      "N+1 on active_storage_blobs (#{single_id_selects} single-id SELECTs after partial render): #{sqls.join("\n")}"
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
