# frozen_string_literal: true

class ReportSectionComponent < ViewComponent::Base
  def initialize(number:, title:, anchor:, beginner_mode: false, beginner_summary: nil)
    @number = number
    @title = title
    @anchor = anchor
    @beginner_mode = beginner_mode
    @beginner_summary = beginner_summary
  end

  attr_reader :number, :title, :anchor, :beginner_mode, :beginner_summary

  def show_beginner_summary?
    beginner_mode && beginner_summary.present?
  end
end
