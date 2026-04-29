require "test_helper"

class SubPathTest < ActiveSupport::TestCase
  def with_env(value)
    original = ENV["RAILS_RELATIVE_URL_ROOT"]
    if value.nil?
      ENV.delete("RAILS_RELATIVE_URL_ROOT")
    else
      ENV["RAILS_RELATIVE_URL_ROOT"] = value
    end
    yield
  ensure
    ENV["RAILS_RELATIVE_URL_ROOT"] = original
  end

  test ".prefix returns empty string when env unset" do
    with_env(nil) { assert_equal "", SubPath.prefix }
  end

  test ".prefix returns env value with trailing slash trimmed" do
    with_env("/real-estate-auction/") { assert_equal "/real-estate-auction", SubPath.prefix }
  end

  test ".prefix returns env value untouched when no trailing slash" do
    with_env("/real-estate-auction") { assert_equal "/real-estate-auction", SubPath.prefix }
  end

  test ".path_under prepends prefix to a leading-slash path" do
    with_env("/real-estate-auction") do
      assert_equal "/real-estate-auction/up", SubPath.path_under("/up")
    end
  end

  test ".path_under returns path unchanged when env unset" do
    with_env(nil) { assert_equal "/up", SubPath.path_under("/up") }
  end

  test ".path_under handles env with trailing slash" do
    with_env("/foo/") { assert_equal "/foo/up", SubPath.path_under("/up") }
  end
end
