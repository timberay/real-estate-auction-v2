require "test_helper"
require "yaml"

class DeployYamlTest < ActiveSupport::TestCase
  test "Kamal deploy config defines Docker log rotation" do
    config = YAML.load_file(Rails.root.join("config/deploy.yml"))

    assert_equal "json-file", config.dig("logging", "driver"),
      "logging.driver must be json-file so max-size/max-file options apply"

    options = config.dig("logging", "options") || {}
    assert_equal "100m", options["max-size"],
      "logging.options.max-size must cap a single log file (Cafe24 4GB disk safety)"
    assert_equal "5", options["max-file"].to_s,
      "logging.options.max-file must cap retained rotated files"
  end
end
