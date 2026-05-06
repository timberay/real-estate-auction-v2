class StaticLoanPolicyAdapter < LoanPolicyAdapter
  # Read policies from the same JSON file db/seeds.rb uses so the seed and
  # the sync-service source can never drift. The file is the canonical
  # store; this adapter just deserializes it.
  SEED_PATH = Rails.root.join("db/seeds/loan_policies.json").freeze

  def fetch_policies(property_type_code:)
    self.class.policies_by_code.fetch(property_type_code, [])
  end

  def self.policies_by_code
    @policies_by_code ||= load_policies
  end

  # Useful for tests or after editing the JSON in a `rails console` session.
  def self.reload!
    @policies_by_code = load_policies
  end

  def self.load_policies
    raw = JSON.parse(File.read(SEED_PATH))
    raw.each_with_object({}) do |group, acc|
      acc[group["property_type_code"]] = group["policies"].map do |p|
        {
          policy_name: p["policy_name"],
          loan_ratio: p["loan_ratio"],
          regulated_loan_ratio: p["regulated_loan_ratio"],
          description: p["description"],
          source_url: p["source_url"],
          effective_date: Date.parse(p["effective_date"])
        }
      end.freeze
    end.freeze
  end
  private_class_method :load_policies
end
