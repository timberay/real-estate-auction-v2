class SeedCheck
  CHECKS = [
    [ "PropertyType (enabled)", -> { PropertyType.where(enabled: true).exists? } ],
    [ "ReserveFundDefault",     -> { ReserveFundDefault.exists? } ],
    [ "LoanPolicy",             -> { LoanPolicy.exists? } ],
    [ "InspectionItem",         -> { InspectionItem.exists? } ],
    [ "EvictionStep",           -> { EvictionStep.exists? } ],
    [ "EvictionSimulatorQuestion", -> { EvictionSimulatorQuestion.exists? } ]
  ].freeze

  def self.empty_critical_tables
    CHECKS.reject { |_, check| check.call }.map(&:first)
  end

  def self.report!(io: $stderr)
    empties = empty_critical_tables
    return false if empties.empty?

    io.puts "[SeedCheck] Empty critical seed tables: #{empties.join(', ')}"
    io.puts "[SeedCheck] Run `bin/rails db:seed` to repopulate."
    true
  end
end
