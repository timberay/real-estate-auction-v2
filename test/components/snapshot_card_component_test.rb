# frozen_string_literal: true

require "test_helper"

class SnapshotCardComponentTest < ViewComponent::TestCase
  def default_props
    {
      version: 3,
      trigger: "manual_edit",
      max_bid_amount: 150000000,
      calculated_at: Time.zone.local(2025, 1, 15, 10, 30),
      show_path: "/snapshots/3",
      recalculate_path: "/snapshots/3/recalculate"
    }
  end

  # --- Basic rendering ---

  test "renders version number" do
    render_inline(SnapshotCardComponent.new(**default_props))

    assert_text "v3"
  end

  # --- Trigger badge ---

  test "renders trigger badge for manual_edit" do
    render_inline(SnapshotCardComponent.new(**default_props))

    assert_selector "span[class*='bg-green-50']"
  end

  test "renders trigger badge for onboarding" do
    render_inline(SnapshotCardComponent.new(**default_props.merge(trigger: "onboarding")))

    assert_selector "span[class*='bg-blue-50']"
  end

  test "renders trigger badge for recalculate" do
    render_inline(SnapshotCardComponent.new(**default_props.merge(trigger: "recalculate")))

    assert_selector "span[class*='bg-yellow-50']"
  end

  # --- Formatted amount ---

  test "renders formatted max bid amount" do
    render_inline(SnapshotCardComponent.new(**default_props))

    assert_text "150,000,000"
  end

  # --- Action links ---

  test "renders show action link" do
    render_inline(SnapshotCardComponent.new(**default_props))

    assert_selector "a[href='/snapshots/3']"
  end

  test "renders recalculate action link" do
    render_inline(SnapshotCardComponent.new(**default_props))

    assert_selector "a[href='/snapshots/3/recalculate']"
  end

  # --- Container ---

  test "renders container with correct styling" do
    render_inline(SnapshotCardComponent.new(**default_props))

    assert_selector "div[class*='border']"
    assert_selector "div[class*='rounded-lg']"
    assert_selector "div[class*='p-4']"
    assert_selector "div[class*='bg-white']"
  end

  # --- Dark mode ---

  test "includes dark mode classes" do
    render_inline(SnapshotCardComponent.new(**default_props))

    assert_selector "div[class*='dark:bg-slate-800']"
  end

  # --- Hover ---

  test "includes hover class" do
    render_inline(SnapshotCardComponent.new(**default_props))

    assert_selector "div[class*='hover:bg-slate-50']"
  end
end
