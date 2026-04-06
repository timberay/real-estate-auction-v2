class RegistryTranscriptAdapter
  def self.for
    if ENV["USE_MOCK"] == "false"
      raise NotImplementedError, "Real registry transcript adapter not yet implemented"
    else
      MockRegistryTranscriptAdapter.new
    end
  end

  def fetch_data(case_number:)
    raise NotImplementedError, "#{self.class}#fetch_data must be implemented"
  end
end
