require "test_helper"

class CourtAuctionErrorMessagesTest < ActiveSupport::TestCase
  class Host
    include CourtAuctionErrorMessages
  end

  setup { @host = Host.new }

  test "TimeoutError → 데이터 수집 시간 메시지" do
    msg = @host.send(:error_message_for, DataProvider::TimeoutError.new)
    assert_match "데이터 수집 시간이 초과", msg
  end

  test "ServiceUnavailableError → 사이트 접속 메시지" do
    msg = @host.send(:error_message_for, DataProvider::ServiceUnavailableError.new)
    assert_match "법원경매 사이트에 접속할 수 없습니다", msg
  end

  test "ConnectionError → 사이트 접속 메시지" do
    msg = @host.send(:error_message_for, DataProvider::ConnectionError.new)
    assert_match "법원경매 사이트에 접속할 수 없습니다", msg
  end

  test "ConfigurationError → 시스템 설정 메시지" do
    msg = @host.send(:error_message_for, DataProvider::ConfigurationError.new)
    assert_match "시스템 설정", msg
  end

  test "DataNotFoundError → 찾을 수 없습니다" do
    msg = @host.send(:error_message_for, DataProvider::DataNotFoundError.new)
    assert_match "찾을 수 없습니다", msg
  end

  test "nil → 찾을 수 없습니다" do
    msg = @host.send(:error_message_for, nil)
    assert_match "찾을 수 없습니다", msg
  end

  test "unknown error → 일반 오류" do
    msg = @host.send(:error_message_for, StandardError.new("anything"))
    assert_match "오류가 발생", msg
  end
end
