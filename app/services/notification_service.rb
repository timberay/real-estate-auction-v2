class NotificationService
  CHANNEL_PREFIX = "user_".freeze

  def self.create_for(user:, kind:, title:, body: nil, action_url: nil, email: true)
    notification = user.notifications.create!(
      kind: kind, title: title, body: body, action_url: action_url
    )

    broadcast_badge(user)

    if email && user.email.present?
      NotificationMailer.notify(notification).deliver_later
    end

    notification
  end

  def self.broadcast_badge(user)
    Turbo::StreamsChannel.broadcast_replace_to(
      channel_name(user),
      target: "notification_badge",
      partial: "notifications/badge",
      locals: { unread_count: user.notifications.unread.count }
    )
  rescue => e
    Rails.logger.error "[NotificationService] badge broadcast failed: #{e.message}"
  end

  def self.channel_name(user)
    "#{CHANNEL_PREFIX}#{user.id}_notifications"
  end
end
