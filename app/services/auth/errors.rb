module Auth
  class Error < StandardError; end
  class ProviderError        < Error; end
  class EmailMissingError    < Error; end
  class IdentityConflictError < Error; end
  class MergeError           < Error; end
end
