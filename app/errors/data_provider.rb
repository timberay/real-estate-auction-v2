module DataProvider
  class Error < StandardError; end

  # Credential errors — user action required
  class MissingCredentialError < Error; end
  class InvalidCredentialError < Error; end
  class ExpiredCredentialError < Error; end

  # External service errors — transient, retry may help
  class ConnectionError < Error; end
  class TimeoutError < Error; end
  class RateLimitError < Error; end
  class ServiceUnavailableError < Error; end

  # Data errors — request-specific
  class DataNotFoundError < Error; end
  class ParseError < Error; end

  # Configuration errors — setup required
  class ConfigurationError < Error; end

  # Scraping-specific
  class ConsentRequiredError < Error; end
  class SiteStructureChangedError < Error; end
  class CaptchaError < Error; end
  class IpBlockedError < Error; end
end
