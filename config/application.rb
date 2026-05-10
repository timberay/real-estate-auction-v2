require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Load .env variables in development only (test uses .env.test if present)
if defined?(Dotenv)
  Dotenv.load(".env.test", ".env") if Rails.env.test?
  Dotenv.load if Rails.env.development?
end

module RealEstateAuction
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # All user-facing date/time arithmetic (e.g., 매각기일 D-day) targets KST.
    config.time_zone = "Asia/Seoul"
    # config.eager_load_paths << Rails.root.join("extras")

    # Default to Korean for all user-facing copy (validation messages,
    # ActiveRecord attribute names, etc). Falls back to English when a
    # translation is missing — this keeps the app functional during
    # gradual locale rollout without exposing missing-translation strings.
    config.i18n.default_locale = :ko
    config.i18n.available_locales = [ :ko, :en ]
    config.i18n.fallbacks = [ :en ]
  end
end
