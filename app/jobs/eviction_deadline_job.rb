class EvictionDeadlineJob < ApplicationJob
  queue_as :default

  MILESTONES = [ 30, 7, 0 ].freeze

  def perform
    UserProperty.where.not(payment_completed_on: nil).find_each do |up|
      days = up.days_to_eviction_deadline
      next unless MILESTONES.include?(days)
      next if notified?(up, days)
      notify(up, days)
    end
  end

  private

  def notified?(user_property, days)
    user_property.user.notifications.exists?(
      kind: kind_for(days),
      action_url: action_url_for(user_property.property)
    )
  end

  def notify(user_property, days)
    NotificationService.create_for(
      user: user_property.user,
      kind: kind_for(days),
      title: title_for(user_property, days),
      body: body_for(user_property, days),
      action_url: action_url_for(user_property.property)
    )
  end

  def kind_for(days)
    "eviction_deadline_d#{days}"
  end

  def title_for(user_property, days)
    case_no = user_property.property.case_number
    if days == 0
      "오늘 인도명령 신청 마감일입니다 (#{case_no})"
    else
      "인도명령 신청 마감 #{days}일 전 (#{case_no})"
    end
  end

  def body_for(user_property, days)
    deadline = user_property.eviction_deadline.strftime("%Y.%m.%d")
    "매각대금 납부일로부터 6개월(#{deadline}) 이내에 인도명령을 신청하지 않으면, " \
      "이후에는 명도소송으로만 진행해야 합니다."
  end

  def action_url_for(property)
    Rails.application.routes.url_helpers.property_path(property)
  end
end
