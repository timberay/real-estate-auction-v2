module SubPath
  def self.prefix
    ENV.fetch("RAILS_RELATIVE_URL_ROOT", "").chomp("/")
  end

  def self.path_under(path)
    "#{prefix}#{path}"
  end
end
