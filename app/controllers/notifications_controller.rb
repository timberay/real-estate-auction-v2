class NotificationsController < ApplicationController
  def index
    @notifications = current_user.notifications.ordered_recent
    @total_count   = @notifications.size
    @unread_count  = current_user.notifications.unread.count
  end

  def mark_read
    notification = current_user.notifications.find_by(id: params[:id])
    if notification
      notification.mark_read!
      NotificationService.broadcast_badge(current_user)
      redirect_to notifications_path
    else
      head :not_found
    end
  end
end
