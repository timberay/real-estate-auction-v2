require "test_helper"

class ChecklistCodeMappingTest < ActiveSupport::TestCase
  test "build_checklist_refs returns code+question pairs in input order" do
    refs = ChecklistCodeMapping.build_checklist_refs(%w[rights-002 rights-003])
    assert_equal 2, refs.size
    assert_equal "rights-002", refs[0][:code]
    assert refs[0][:question].present?
    assert_equal "rights-003", refs[1][:code]
  end

  test "build_checklist_refs marks missing codes as nil question" do
    refs = ChecklistCodeMapping.build_checklist_refs(%w[rights-002 nonexistent-code])
    assert_equal "rights-002", refs[0][:code]
    assert refs[0][:question].present?
    assert_equal "nonexistent-code", refs[1][:code]
    assert_nil refs[1][:question]
  end

  test "build_checklist_refs returns empty array for empty input" do
    assert_equal [], ChecklistCodeMapping.build_checklist_refs([])
    assert_equal [], ChecklistCodeMapping.build_checklist_refs(nil)
  end

  test "build_checklist_refs issues a single query" do
    queries = []
    callback = ->(_, _, _, _, payload) {
      sql = payload[:sql]
      queries << sql if sql =~ /\bFROM\s+"?inspection_items"?\b/i && sql !~ /sqlite_master|PRAGMA/i
    }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      ChecklistCodeMapping.build_checklist_refs(%w[rights-002 rights-003 rights-006])
    end
    assert_equal 1, queries.size, "expected exactly one inspection_items SELECT, got: #{queries}"
  end
end
