require "test_helper"

class EvictionSimulationTest < ActiveSupport::TestCase
  test "valid property-linked simulation" do
    sim = EvictionSimulation.new(
      property: properties(:safe_apartment),
      answers: { "Q1" => true },
      completed: false
    )
    assert sim.valid?
  end

  test "valid standalone simulation" do
    sim = EvictionSimulation.new(
      session_id: "abc123",
      answers: { "Q1" => true },
      completed: false
    )
    assert sim.valid?
  end

  test "one simulation per property" do
    EvictionSimulation.create!(
      property: properties(:risky_villa),
      answers: {}, completed: false
    )
    dup = EvictionSimulation.new(
      property: properties(:risky_villa),
      answers: {}, completed: false
    )
    assert_not dup.valid?
  end

  test "OCCUPANT_TYPES contains the 4 valid types" do
    assert_equal %w[junior_tenant senior_tenant debtor_owner illegal_occupant],
                 EvictionSimulation::OCCUPANT_TYPES
  end

  test "valid_occupant_type? returns true for valid types" do
    EvictionSimulation::OCCUPANT_TYPES.each do |type|
      sim = EvictionSimulation.new(occupant_type: type)
      assert sim.valid_occupant_type?, "Expected #{type} to be valid"
    end
  end

  test "valid_occupant_type? returns false for invalid types" do
    sim = EvictionSimulation.new(occupant_type: "unknown_type")
    assert_not sim.valid_occupant_type?
  end

  test "valid_occupant_type? returns true for nil (legacy)" do
    sim = EvictionSimulation.new(occupant_type: nil)
    assert sim.valid_occupant_type?
  end

  test "occupant_type_label returns Korean label" do
    sim = eviction_simulations(:junior_tenant_sim)
    assert_equal "후순위 임차인 (배당 수령)", sim.occupant_type_label
  end

  test "occupant_type_label returns nil for legacy simulation" do
    sim = eviction_simulations(:standalone)
    assert_nil sim.occupant_type_label
  end

  test "base_difficulty returns difficulty for occupant type" do
    sim = eviction_simulations(:junior_tenant_sim)
    assert_equal "low", sim.base_difficulty
  end

  test "stale scope returns old standalone records" do
    old = EvictionSimulation.create!(
      session_id: "old_session", answers: {}, completed: false,
      created_at: 2.days.ago
    )
    recent = EvictionSimulation.create!(
      session_id: "new_session", answers: {}, completed: false
    )
    stale = EvictionSimulation.stale
    assert_includes stale, old
    assert_not_includes stale, recent
  end
end
