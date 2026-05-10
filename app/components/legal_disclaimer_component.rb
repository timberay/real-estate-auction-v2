class LegalDisclaimerComponent < ViewComponent::Base
  def initialize(compact: false)
    @compact = compact
  end

  def compact?
    @compact
  end
end
