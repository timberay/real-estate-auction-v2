require "test_helper"

class DataProviderErrorTest < ActiveSupport::TestCase
  test "all errors inherit from DataProvider::Error" do
    error_classes = [
      DataProvider::MissingCredentialError,
      DataProvider::InvalidCredentialError,
      DataProvider::ConnectionError,
      DataProvider::RateLimitError,
      DataProvider::ServiceUnavailableError,
      DataProvider::DataNotFoundError,
      DataProvider::ParseError,
      DataProvider::ConsentRequiredError,
      DataProvider::SiteStructureChangedError
    ]

    error_classes.each do |klass|
      assert klass < DataProvider::Error, "#{klass} should inherit from DataProvider::Error"
      assert klass < StandardError, "#{klass} should inherit from StandardError"
    end
  end

  test "errors can be instantiated with a message" do
    error = DataProvider::MissingCredentialError.new("API 키를 설정해주세요.")
    assert_equal "API 키를 설정해주세요.", error.message
  end

  test "rescue DataProvider::Error catches all subclasses" do
    assert_raises(DataProvider::Error) do
      raise DataProvider::ConnectionError, "timeout"
    end
  end
end
