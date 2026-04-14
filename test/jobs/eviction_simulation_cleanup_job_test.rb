require "test_helper"

class EvictionSimulationCleanupJobTest < ActiveJob::TestCase
  test "deletes stale standalone simulations" do
    stale = EvictionSimulation.create!(
      session_id: "stale", answers: {}, completed: false,
      created_at: 2.days.ago
    )
    recent = EvictionSimulation.create!(
      session_id: "recent", answers: {}, completed: false
    )
    linked = EvictionSimulation.create!(
      property: properties(:safe_apartment), answers: {}, completed: false,
      created_at: 2.days.ago
    )

    EvictionSimulationCleanupJob.perform_now

    assert_not EvictionSimulation.exists?(stale.id), "Stale standalone should be deleted"
    assert EvictionSimulation.exists?(recent.id), "Recent standalone should survive"
    assert EvictionSimulation.exists?(linked.id), "Property-linked should survive regardless of age"
  end
end
