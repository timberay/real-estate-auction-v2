require "test_helper"

# F-D-3 — append-only ledger of admin mutations on AcquisitionTaxRate.
# Notes:
#   - acquisition_tax_rate_id is nullable so destroyed rows still leave a trail.
#   - user_id is required: every change must be attributable.
#   - changes_json is required: an audit row with no payload is useless.
class AcquisitionTaxRateAuditLogTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin_user)
    @rate  = acquisition_tax_rates(:apartment_homeless_under6_under85)
  end

  test "valid log with all required fields" do
    log = AcquisitionTaxRateAuditLog.new(
      acquisition_tax_rate: @rate,
      user: @admin,
      action: "created",
      changes_json: { after: { total_rate: 0.011 } }.to_json
    )
    assert log.valid?, log.errors.full_messages.inspect
  end

  test "user is required" do
    log = AcquisitionTaxRateAuditLog.new(
      acquisition_tax_rate: @rate,
      action: "created",
      changes_json: "{}"
    )
    refute log.valid?
    assert log.errors[:user].any?
  end

  test "action must be one of the whitelisted values" do
    log = AcquisitionTaxRateAuditLog.new(
      acquisition_tax_rate: @rate,
      user: @admin,
      action: "fiddled",
      changes_json: "{}"
    )
    refute log.valid?
    assert log.errors[:action].any?
  end

  test "changes_json presence is enforced" do
    log = AcquisitionTaxRateAuditLog.new(
      acquisition_tax_rate: @rate,
      user: @admin,
      action: "updated",
      changes_json: nil
    )
    refute log.valid?
    assert log.errors[:changes_json].any?
  end

  test "acquisition_tax_rate may be nil so destroyed-row trail survives" do
    log = AcquisitionTaxRateAuditLog.new(
      acquisition_tax_rate: nil,
      user: @admin,
      action: "destroyed",
      changes_json: { before: { total_rate: 0.011 } }.to_json
    )
    assert log.valid?, log.errors.full_messages.inspect
  end
end
