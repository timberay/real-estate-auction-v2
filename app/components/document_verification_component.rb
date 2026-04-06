class DocumentVerificationComponent < ViewComponent::Base
  def initialize(report:, property:)
    @report = report
    @property = property
  end

  private

  def confirmed?
    @report.user_confirmed_at.present?
  end

  def key_items
    @report.verdict_summary&.split("\n")&.reject(&:blank?) || []
  end
end
