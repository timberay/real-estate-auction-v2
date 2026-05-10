require "application_system_test_case"

# B10 / E-21: Per-property memo + 임장 date + photo attachment.
# Verifies the 내 메모 / 임장 노트 card on the property show page:
# - Notes and inspection date can be entered and saved inline.
# - Photos can be uploaded and thumbnails displayed.
# - Photos can be deleted.
class UserPropertyNotesTest < ApplicationSystemTestCase
  setup do
    @property = properties(:safe_apartment)
    @user = users(:budget_user)
    UserProperty.find_or_create_by!(user: @user, property: @property)
    sign_in_as(@user)
  end

  test "property show page renders 내 메모 / 임장 노트 card" do
    visit property_path(@property)
    assert_selector "h3", text: "내 메모 / 임장 노트"
  end

  test "clicking 메모 편집 opens the edit form" do
    visit property_path(@property)
    click_link "메모 편집"
    assert_selector "textarea[name='user_property[notes]']"
    assert_selector "input[name='user_property[inspection_visited_on]']"
  end

  test "saving notes shows them in display mode" do
    visit property_path(@property)
    click_link "메모 편집"

    fill_in "user_property[notes]", with: "OO부동산 사장님 시세 8.5억"
    execute_script("document.querySelector('input[name=\"user_property[inspection_visited_on]\"]').value = '2026-05-10'")
    click_button "저장"

    assert_text "OO부동산 사장님 시세 8.5억"
    assert_text "2026.05.10"
    assert_no_selector "textarea[name='user_property[notes]']"
  end

  test "photo upload form is present on the page" do
    visit property_path(@property)
    assert_selector "input[type='file'][accept='image/*']"
    assert_selector "h4", text: "임장 사진"
  end

  test "uploading a photo shows a thumbnail" do
    visit property_path(@property)

    within "turbo-frame#user-property-photos" do
      attach_file "photo", Rails.root.join("test/fixtures/files/test_photo.png")
      click_button "업로드"
    end

    assert_selector "img[alt='임장 사진']"
  end

  test "deleting a photo removes the thumbnail" do
    user_property = UserProperty.find_by!(user: @user, property: @property)
    user_property.photos.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test_photo.png")),
      filename: "test_photo.png",
      content_type: "image/png"
    )

    visit property_path(@property)
    assert_selector "img[alt='임장 사진']"

    within "turbo-frame#user-property-photos" do
      find("button", text: "×").click
    end

    assert_no_selector "img[alt='임장 사진']"
  end
end
