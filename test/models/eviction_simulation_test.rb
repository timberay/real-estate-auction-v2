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
