class NotificationMailer < ApplicationMailer
  def notify(notification)
    @notification = notification
    @user = notification.user
    mail(to: @user.email, subject: @notification.title)
  end
end
