# frozen_string_literal: true

class ReportSectionComponent < ViewComponent::Base
  def initialize(number:, title:, anchor:)
    @number = number
    @title = title
    @anchor = anchor
  end

  attr_reader :number, :title, :anchor
end
