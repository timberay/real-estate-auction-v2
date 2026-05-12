if Rails.env.development?
  Rails.application.config.after_initialize do
    next unless defined?(Rails::Server)

    begin
      next unless ActiveRecord::Base.connection.table_exists?("property_types")
      SeedCheck.report!
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
      # Database not ready yet (e.g. pre-migration). Skip silently.
    end
  end
end
