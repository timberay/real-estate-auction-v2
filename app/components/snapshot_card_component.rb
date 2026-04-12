# frozen_string_literal: true

class SnapshotCardComponent < ViewComponent::Base
  include ActiveSupport::NumberHelper

  TRIGGER_VARIANTS = {
    "onboarding" => :info,
    "manual_edit" => :success,
    "recalculate" => :warning
  }.freeze

  CONTAINER_CLASSES = "border border-slate-200 dark:border-slate-700 rounded-lg p-4 bg-white dark:bg-slate-800 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors"

  def initialize(version:, trigger:, max_bid_amount:, calculated_at:, show_path:, recalculate_path:)
    @version = version
    @trigger = trigger
    @max_bid_amount = max_bid_amount
    @calculated_at = calculated_at
    @show_path = show_path
    @recalculate_path = recalculate_path
  end

  private

  def formatted_amount
    helpers.format_price_won(@max_bid_amount)
  end

  def badge_variant
    TRIGGER_VARIANTS[@trigger.to_s] || :default
  end

  def formatted_date
    @calculated_at.strftime("%Y-%m-%d %H:%M")
  end
end
