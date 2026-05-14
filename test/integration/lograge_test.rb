require "test_helper"

class LograteTest < ActionDispatch::IntegrationTest
  setup do
    @io = StringIO.new
    @prev_lograge_logger = Lograge.logger
    Lograge.logger = ActiveSupport::Logger.new(@io)
  end

  teardown do
    Lograge.logger = @prev_lograge_logger
  end

  test "produces a single JSON line per request with the expected payload fields" do
    get root_url

    json_lines = parse_json_lines(@io.string)
    assert_equal 1, json_lines.size, "expected exactly one JSON log line, got #{json_lines.size}: #{@io.string.inspect}"

    line = json_lines.first
    %w[method path format controller action status duration request_id remote_ip].each do |key|
      assert_includes line.keys, key, "missing key #{key} in lograge payload: #{line.inspect}"
    end
    assert_equal "GET", line["method"]
    assert_kind_of Numeric, line["status"]
  end

  test "lograge payload includes user_id and guest flag once a user is in session" do
    get start_onboarding_url
    user = User.find(session[:user_id])

    @io.truncate(0); @io.rewind

    get properties_url

    line = parse_json_lines(@io.string).first
    assert_equal user.id, line["user_id"]
    assert_equal user.guest?, line["guest"]
  end

  test "lograge payload sets user_id to nil when no session user" do
    get root_url
    line = parse_json_lines(@io.string).first
    assert_nil line["user_id"]
  end

  private

  def parse_json_lines(raw)
    raw.lines.map(&:strip).reject(&:empty?).map { |l| JSON.parse(l) rescue nil }.compact
  end
end
