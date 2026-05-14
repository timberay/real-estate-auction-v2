Rails.application.configure do
  # One structured JSON line per request. Replaces Rails' multi-line request
  # logging in production + test so logs are grep-/jq-friendly. Disabled in
  # development to keep the verbose human-readable output devs rely on.
  config.lograge.enabled = !Rails.env.development?
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.lograge.keep_original_rails_log = false

  config.lograge.custom_payload do |controller|
    user = controller.respond_to?(:current_user, true) ? controller.send(:current_user) : nil
    {
      request_id: controller.request.request_id,
      remote_ip: controller.request.remote_ip,
      user_id: user&.id,
      guest: user.respond_to?(:guest?) ? user.guest? : nil
    }
  end

  config.lograge.custom_options = lambda do |event|
    exception = event.payload[:exception_object]
    options = { params: event.payload[:params]&.except("controller", "action", "format", "id") }
    if exception
      options[:exception] = { class: exception.class.name, message: exception.message }
    end
    options
  end
end
