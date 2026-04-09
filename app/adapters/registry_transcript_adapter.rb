class RegistryTranscriptAdapter
  def self.for(config = {})
    if config[:adapter] == :real
      MockRegistryTranscriptAdapter.new  # Real adapters defined in individual source specs
    else
      MockRegistryTranscriptAdapter.new
    end
  end

  def fetch_data(case_number:)
    raise NotImplementedError, "#{self.class}#fetch_data must be implemented"
  end
end
