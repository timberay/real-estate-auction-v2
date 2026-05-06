require "test_helper"

class TestingControllerTest < ActionDispatch::IntegrationTest
  test "set_remember_cookie works in test env" do
    user = User.create!(guest: false, email: "tc@example.com", name: "TC")
    post "/testing/set_remember_cookie", params: { user_id: user.id }
    assert_response :ok
  end

  test "ensure_test_env raises when Rails.env is not test" do
    controller = TestingController.new
    with_rails_env("production") do
      err = assert_raises(RuntimeError) { controller.send(:ensure_test_env) }
      assert_match(/test/i, err.message)
    end
  end

  test "ensure_test_env is a no-op in test env" do
    controller = TestingController.new
    assert_nil controller.send(:ensure_test_env)
  end

  private

  def with_rails_env(env_name)
    original = Rails.instance_variable_get(:@_env)
    Rails.instance_variable_set(:@_env, ActiveSupport::StringInquirer.new(env_name))
    yield
  ensure
    Rails.instance_variable_set(:@_env, original)
  end
end
