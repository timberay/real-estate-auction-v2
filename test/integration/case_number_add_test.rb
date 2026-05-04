require "test_helper"

class CaseNumberAddTest < ActionDispatch::IntegrationTest
  ENDPOINT = "https://www.courtauction.go.kr/pgj/pgj15A/selectAuctnCsSrchRslt.on"

  setup do
    get start_onboarding_url
    @user = inherit_fixture_guest_ownership
  end

  test "user adds case from external source via court+case form" do
    fixture = File.read(Rails.root.join("test/fixtures/files/court_auction_case_search_valid.json"))
    stub_request(:post, ENDPOINT).to_return(status: 200, body: fixture)

    # Page renders with court select
    get properties_path
    assert_response :success
    assert_select "select[name=court_code][required]"
    assert_select "input[name=case_number][required]"
    assert_match "법원과 사건번호를 입력해주세요", response.body

    # Submit form
    post properties_path, params: { court_code: "B000530", case_number: "2022타경564" }
    follow_redirect!  # -> property_path (show redirects to analyses/new)
    follow_redirect!  # -> analyses/new

    # Analysis page shows the new property's case number
    assert_response :success
    assert_match "2022타경564", response.body
  end

  test "user submitting bad format sees flash without HTTP call" do
    post properties_path, params: { court_code: "B000530", case_number: "bad-format" }
    follow_redirect!
    assert_match "사건번호 형식이 올바르지 않습니다", response.body
  end
end
