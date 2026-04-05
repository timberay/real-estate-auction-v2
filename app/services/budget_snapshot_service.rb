class BudgetSnapshotService
  COMPARABLE_FIELDS = %i[
    available_cash repair_cost acquisition_tax scrivener_fee
    moving_cost maintenance_fee loan_ratio max_bid_amount
    failed_auction_rounds searchable_appraisal_limit
  ].freeze

  NUMERIC_FIELDS = %i[
    available_cash repair_cost acquisition_tax scrivener_fee
    moving_cost maintenance_fee max_bid_amount
    failed_auction_rounds searchable_appraisal_limit
  ].freeze

  def self.create(user:, trigger:)
    new(user:).create(trigger:)
  end

  def self.recalculate(user:, parent_snapshot:)
    new(user:).recalculate(parent_snapshot:)
  end

  def self.compare(snapshot_a:, snapshot_b:)
    new(user: snapshot_a.user).compare(snapshot_a:, snapshot_b:)
  end

  def initialize(user:)
    @user = user
  end

  def create(trigger:)
    setting = @user.budget_setting
    version = BudgetSnapshot.next_version_for(@user.id)

    BudgetSnapshot.create!(
      user: @user,
      version: version,
      trigger: trigger,
      available_cash: setting.available_cash,
      property_type_name: setting.property_type&.name,
      area_range: format_area_range(setting),
      area_unit: setting.area_unit,
      repair_cost: setting.repair_cost,
      acquisition_tax: setting.acquisition_tax,
      scrivener_fee: setting.scrivener_fee,
      moving_cost: setting.moving_cost,
      maintenance_fee: setting.maintenance_fee,
      loan_policy_name: setting.loan_policy&.policy_name,
      loan_ratio: setting.loan_ratio,
      max_bid_amount: setting.max_bid_amount,
      failed_auction_rounds: setting.failed_auction_rounds,
      searchable_appraisal_limit: setting.searchable_appraisal_limit,
      calculated_at: Time.current
    )
  end

  def recalculate(parent_snapshot:)
    setting = @user.budget_setting
    version = BudgetSnapshot.next_version_for(@user.id)

    BudgetSnapshot.create!(
      user: @user,
      version: version,
      trigger: "recalculate",
      parent_snapshot: parent_snapshot,
      available_cash: setting.available_cash,
      property_type_name: setting.property_type&.name,
      area_range: format_area_range(setting),
      area_unit: setting.area_unit,
      repair_cost: setting.repair_cost,
      acquisition_tax: setting.acquisition_tax,
      scrivener_fee: setting.scrivener_fee,
      moving_cost: setting.moving_cost,
      maintenance_fee: setting.maintenance_fee,
      loan_policy_name: setting.loan_policy&.policy_name,
      loan_ratio: setting.loan_ratio,
      max_bid_amount: setting.max_bid_amount,
      failed_auction_rounds: setting.failed_auction_rounds,
      searchable_appraisal_limit: setting.searchable_appraisal_limit,
      calculated_at: Time.current
    )
  end

  def compare(snapshot_a:, snapshot_b:)
    diff = {}

    COMPARABLE_FIELDS.each do |field|
      val_a = normalize_value(snapshot_a.public_send(field))
      val_b = normalize_value(snapshot_b.public_send(field))

      next if val_a == val_b

      entry = { was: val_a, now: val_b }
      entry[:delta] = val_b - val_a if NUMERIC_FIELDS.include?(field) && val_a.is_a?(Numeric) && val_b.is_a?(Numeric)
      diff[field] = entry
    end

    diff
  end

  private

  def format_area_range(setting)
    return nil unless setting.area_range_min && setting.area_range_max
    "#{setting.area_range_min}~#{setting.area_range_max}㎡"
  end

  def normalize_value(val)
    val.is_a?(BigDecimal) ? val.to_f : val
  end
end
