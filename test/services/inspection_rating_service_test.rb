require "test_helper"
require "ostruct"

class InspectionRatingServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
    @property = properties(:safe_apartment)
    @item = inspection_items(:rights_003)
    InspectionResult.where(property: @property, user: @user).destroy_all
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  # Answers ALL visible priority='상' items as no-risk so the A7 gate passes.
  # Items in `except` are skipped — the caller creates those results separately (and may set has_risk: true).
  # `except_has_risk`: treat excepted items as has_risk: true when computing visibility of dependent items.
  # Iterates up to 5 passes to resolve chains of conditional visibility.
  def answer_all_high_priority_no_risk(except: nil, except_has_risk: true)
    excluded_codes = Array(except).map(&:code)
    all_items_by_code = InspectionItem.all.index_by(&:code)
    property_type = @property.property_type

    # Build a fake answered_context for excepted items so conditional dependents become visible
    fake_results = excluded_codes.filter_map do |code|
      item = all_items_by_code[code]
      next unless item
      stub = OpenStruct.new(has_risk: except_has_risk ? true : false, inspection_item: item)
      [ code, stub ]
    end.to_h

    5.times do
      db_results = @property.inspection_results.where(user: @user).includes(:inspection_item)
      answered_context = db_results.index_by { |r| r.inspection_item.code }.merge(fake_results)

      created_any = false
      InspectionItem.where(priority: "상").each do |item|
        next if excluded_codes.include?(item.code)
        next unless item.visible_for?(property_type: property_type, answered_results: answered_context, all_items_by_code: all_items_by_code)
        next if db_results.map { |r| r.inspection_item.code }.include?(item.code)

        InspectionResult.create!(property: @property, inspection_item: item, user: @user, source_type: "auto", has_risk: false)
        created_any = true
      end

      break unless created_any
    end
  end

  test "rates safe when no risks" do
    # All priority='상' items answered no-risk → gate passes → :safe
    answer_all_high_priority_no_risk
    rating = InspectionRatingService.call(property: @property, user: @user)
    assert_equal :safe, rating
    assert_equal "safe", UserProperty.find_by(user: @user, property: @property).safety_rating
  end

  test "rates caution when risks are all resolvable" do
    # Gate requires all priority='상' answered; answer others no-risk, leave @item as the risk
    answer_all_high_priority_no_risk(except: @item)
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: true)
    rating = InspectionRatingService.call(property: @property, user: @user)
    assert_equal :caution, rating
  end

  test "rates danger when any risk is unresolvable" do
    answer_all_high_priority_no_risk(except: @item)
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: false)
    rating = InspectionRatingService.call(property: @property, user: @user)
    assert_equal :danger, rating
  end

  test "rates danger when risk present but resolvable not yet decided" do
    answer_all_high_priority_no_risk(except: @item)
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: nil)
    rating = InspectionRatingService.call(property: @property, user: @user)
    assert_equal :danger, rating
  end

  test "tab_rating returns danger when risk present but resolvable not yet decided" do
    # tab_rating is unaffected by the A7 gate (gate only applies to overall_rating)
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: nil)
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_equal :danger, service.tab_rating("rights_analysis")
  end

  test "rates caution only when all risks are explicitly marked resolvable" do
    item2 = inspection_items(:rights_002)
    # Skip both @item and item2 in the no-risk setup so we can set specific has_risk values below
    answer_all_high_priority_no_risk(except: [ @item, item2 ])
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: true)
    InspectionResult.create!(property: @property, inspection_item: item2, user: @user, source_type: "auto", has_risk: true, resolvable: nil)
    rating = InspectionRatingService.call(property: @property, user: @user)
    assert_equal :danger, rating
  end

  test "returns incomplete when unanswered items exist" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user)
    rating = InspectionRatingService.call(property: @property, user: @user)
    assert_equal :incomplete, rating
  end

  test "tab_rating returns nil when no results for tab" do
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_nil service.tab_rating("rights_analysis")
  end

  test "tab_rating returns incomplete when unanswered items exist in tab" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user)
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_equal :incomplete, service.tab_rating("rights_analysis")
  end

  test "tab_rating returns safe when all items in tab have no risk" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_equal :safe, service.tab_rating("rights_analysis")
  end

  test "tab_rating returns caution when risks are resolvable in tab" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: true)
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_equal :caution, service.tab_rating("rights_analysis")
  end

  test "tab_rating returns danger when unresolvable risk in tab" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: false)
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_equal :danger, service.tab_rating("rights_analysis")
  end

  test "tab_rating scopes to specific tab only" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: false)
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_equal :danger, service.tab_rating("rights_analysis")
    assert_nil service.tab_rating("profit_analysis")
  end

  # Partial evaluation: call method (Tasks 1)
  # A7: priority='상' coverage gate fires before risk logic.
  # With unanswered priority='상' items, overall_rating must return :incomplete — not :safe or :danger.
  test "rates incomplete when some priority=상 items answered safe and others unanswered" do
    item2 = inspection_items(:rights_002)
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
    InspectionResult.create!(property: @property, inspection_item: item2, user: @user)
    rating = InspectionRatingService.call(property: @property, user: @user)
    assert_equal :incomplete, rating
  end

  test "rates incomplete when answered item has unresolvable risk but other priority=상 items unanswered" do
    item2 = inspection_items(:rights_002)
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: false)
    InspectionResult.create!(property: @property, inspection_item: item2, user: @user)
    rating = InspectionRatingService.call(property: @property, user: @user)
    # A7: gate returns :incomplete before reaching danger logic — coverage < 100%
    assert_equal :incomplete, rating
  end

  # Partial evaluation: tab_rating method (Task 2)
  test "tab_rating rates safe when some tab items answered and others unanswered" do
    item2 = inspection_items(:rights_002)
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
    InspectionResult.create!(property: @property, inspection_item: item2, user: @user)
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_equal :safe, service.tab_rating("rights_analysis")
  end

  # fully_evaluated? (Task 3)
  test "fully_evaluated? returns false when no results exist" do
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_not service.fully_evaluated?
  end

  test "fully_evaluated? returns false when unanswered items exist" do
    item2 = inspection_items(:rights_002)
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
    InspectionResult.create!(property: @property, inspection_item: item2, user: @user)
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_not service.fully_evaluated?
  end

  test "fully_evaluated? returns true when all items answered" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
    service = InspectionRatingService.new(property: @property, user: @user)
    assert service.fully_evaluated?
  end

  # tabs_evaluated_count (Task 4)
  test "tabs_evaluated_count returns counts of evaluated and total tabs" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
    service = InspectionRatingService.new(property: @property, user: @user)
    evaluated, total = service.tabs_evaluated_count
    assert_equal 1, evaluated
    assert_equal 4, total
  end

  test "tabs_evaluated_count counts tab as evaluated when at least one item answered" do
    item_other_tab = inspection_items(:tax_006)
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
    InspectionResult.create!(property: @property, inspection_item: item_other_tab, user: @user, source_type: "auto", has_risk: true, resolvable: true)
    service = InspectionRatingService.new(property: @property, user: @user)
    evaluated, total = service.tabs_evaluated_count
    assert_equal 2, evaluated
    assert_equal 4, total
  end

  # overall_rating: non-mutating read of overall rating (Task: tabs component reuse)
  test "overall_rating returns rating without mutating user_property" do
    # All priority='상' answered (gate passes); @item is the one risk (resolvable) → :caution
    answer_all_high_priority_no_risk(except: @item)
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: true)
    user_property = UserProperty.find_by!(user: @user, property: @property)
    user_property.update!(safety_rating: nil, analyzed_at: nil)

    service = InspectionRatingService.new(property: @property, user: @user)
    rating = service.overall_rating

    assert_equal :caution, rating
    user_property.reload
    assert_nil user_property.safety_rating
    assert_nil user_property.analyzed_at
  end

  test "overall_rating returns incomplete when no items answered" do
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_equal :incomplete, service.overall_rating
  end

  # A7: priority='상' coverage gate
  test "incomplete when priority='상' coverage < 100% even if no risks" do
    # Answer only one priority='상' item as no-risk; leave all others unanswered
    high_item = InspectionItem.where(priority: "상").first
    InspectionResult.create!(property: @property, inspection_item: high_item, user: @user, source_type: "auto", has_risk: false)

    service = InspectionRatingService.new(property: @property, user: @user)
    assert_equal :incomplete, service.overall_rating
  end

  test "unanswered_high_priority_count returns the exact gap" do
    service_baseline = InspectionRatingService.new(property: @property, user: @user)
    baseline_unanswered = service_baseline.unanswered_high_priority_count
    assert baseline_unanswered > 1, "test setup: need at least 2 visible high items"

    # Answer exactly one visible high-priority item (no depends_on so unconditionally visible)
    answerable = InspectionItem.where(priority: "상").find { |item|
      item.applicable_for?(@property.property_type) && item.depends_on.blank?
    }
    InspectionResult.create!(property: @property, inspection_item: answerable, user: @user, source_type: "auto", has_risk: false)

    service_after = InspectionRatingService.new(property: @property, user: @user)
    assert_equal baseline_unanswered - 1, service_after.unanswered_high_priority_count
  end

  test "safe when all visible priority='상' items answered with no risks" do
    answer_all_high_priority_no_risk
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_equal :safe, service.overall_rating
  end

  # M1 N+1 fix: shared item_cache across multiple service instances
  test "build_item_cache returns reference data usable by multiple instances" do
    cache = InspectionRatingService.build_item_cache
    assert_kind_of Hash, cache[:by_code]
    assert_kind_of Array, cache[:high_priority]
    assert cache[:high_priority].all? { |i| i.priority == "상" }
    assert_equal InspectionItem.count, cache[:by_code].size
  end

  test "overall_rating with item_cache matches uncached result" do
    answer_all_high_priority_no_risk(except: @item)
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: true)

    uncached = InspectionRatingService.new(property: @property, user: @user).overall_rating
    cached = InspectionRatingService.new(
      property: @property, user: @user, item_cache: InspectionRatingService.build_item_cache
    ).overall_rating

    assert_equal uncached, cached
    assert_equal :caution, cached
  end

  test "overall_rating with item_cache skips reference-data scans of inspection_items" do
    # Cache eliminates: SELECT * FROM inspection_items (full scan)
    # and          SELECT * FROM inspection_items WHERE priority = ?
    # `includes(:inspection_item)` lookups (WHERE id IN ...) remain — those load
    # records related to specific inspection_results, not the global table.
    answer_all_high_priority_no_risk
    cache = InspectionRatingService.build_item_cache

    reference_scans = []
    callback = lambda do |_n, _s, _f, _i, payload|
      sql = payload[:sql]
      next unless sql =~ /FROM "inspection_items"/i
      next if sql =~ /WHERE "inspection_items"."id" IN/i
      reference_scans << sql
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      InspectionRatingService.new(property: @property, user: @user, item_cache: cache).overall_rating
    end

    assert_empty reference_scans,
                 "expected no full/priority scans of inspection_items when item_cache supplied, got: #{reference_scans.inspect}"
  end
end
