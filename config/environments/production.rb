require "active_support/core_ext/integer/time"
require_relative "../../app/lib/sub_path"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Sub-directory deployment support (e.g., example.com/real-estate-auction/)
  config.relative_url_root = ENV.fetch("RAILS_RELATIVE_URL_ROOT", "/")

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the health check endpoint (Kamal's in-network probe uses plain HTTP).
  # HSTS: 1 year, include subdomains, request preload listing.
  config.ssl_options = {
    redirect: { exclude: ->(request) { request.path == SubPath.path_under("/up") } },
    hsts: { expires: 1.year, subdomains: true, preload: true }
  }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = SubPath.path_under("/up")

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = {
    host: ENV.fetch("MAILER_HOST", "example.com"),
    script_name: SubPath.prefix
  }

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via bin/rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # APP_HOST must be set in production (ENV.fetch raises at boot if missing — intentional fail-fast).
  # Anchored regex prevents crafted Host bypass (e.g. evil.com.host.attacker.net).
  config.hosts = [
    ENV.fetch("APP_HOST"),
    /\A.*\.#{Regexp.escape(ENV.fetch("APP_HOST"))}\z/
  ]

  # Skip DNS rebinding protection for the health check endpoint (Kamal's in-network probe uses plain HTTP).
  config.host_authorization = { exclude: ->(request) { request.path == SubPath.path_under("/up") } }
end
