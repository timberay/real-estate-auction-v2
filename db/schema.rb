# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_06_010133) do
  create_table "budget_settings", force: :cascade do |t|
    t.integer "acquisition_tax"
    t.integer "area_range_max"
    t.integer "area_range_min"
    t.string "area_unit", default: "pyeong", null: false
    t.integer "available_cash"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "failed_auction_rounds", default: 0, null: false
    t.integer "loan_policy_id"
    t.decimal "loan_ratio", precision: 3, scale: 2
    t.integer "maintenance_fee"
    t.integer "max_bid_amount"
    t.integer "moving_cost"
    t.integer "property_type_id"
    t.integer "repair_cost"
    t.integer "scrivener_fee"
    t.integer "searchable_appraisal_limit"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["loan_policy_id"], name: "index_budget_settings_on_loan_policy_id"
    t.index ["property_type_id"], name: "index_budget_settings_on_property_type_id"
    t.index ["user_id"], name: "index_budget_settings_on_user_id", unique: true
  end

  create_table "budget_snapshots", force: :cascade do |t|
    t.integer "acquisition_tax"
    t.string "area_range"
    t.string "area_unit"
    t.integer "available_cash"
    t.datetime "calculated_at", null: false
    t.datetime "created_at", null: false
    t.integer "failed_auction_rounds"
    t.string "loan_policy_name"
    t.decimal "loan_ratio", precision: 3, scale: 2
    t.integer "maintenance_fee"
    t.integer "max_bid_amount"
    t.integer "moving_cost"
    t.integer "parent_snapshot_id"
    t.integer "property_case_id"
    t.string "property_type_name"
    t.integer "repair_cost"
    t.integer "scrivener_fee"
    t.integer "searchable_appraisal_limit"
    t.string "trigger", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "version", null: false
    t.index ["parent_snapshot_id"], name: "index_budget_snapshots_on_parent_snapshot_id"
    t.index ["user_id", "version"], name: "index_budget_snapshots_on_user_id_and_version"
    t.index ["user_id"], name: "index_budget_snapshots_on_user_id"
  end

  create_table "checklist_items", force: :cascade do |t|
    t.string "category", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "data_source_name"
    t.text "description"
    t.json "logic"
    t.integer "position", default: 0, null: false
    t.string "priority", default: "상", null: false
    t.text "question", null: false
    t.integer "risk_axis", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_checklist_items_on_code", unique: true
    t.index ["position"], name: "index_checklist_items_on_position"
    t.index ["risk_axis"], name: "index_checklist_items_on_risk_axis"
  end

  create_table "loan_policies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.date "effective_date", null: false
    t.boolean "enabled", default: true, null: false
    t.date "expiry_date"
    t.decimal "loan_ratio", precision: 3, scale: 2, null: false
    t.string "policy_name", null: false
    t.integer "property_type_id", null: false
    t.string "source_url"
    t.datetime "updated_at", null: false
    t.index ["property_type_id", "enabled"], name: "index_loan_policies_on_property_type_id_and_enabled"
    t.index ["property_type_id"], name: "index_loan_policies_on_property_type_id"
  end

  create_table "properties", force: :cascade do |t|
    t.string "address"
    t.integer "appraisal_price"
    t.string "case_number", null: false
    t.string "court_name"
    t.datetime "created_at", null: false
    t.integer "min_bid_price"
    t.string "property_type"
    t.json "raw_data"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["case_number"], name: "index_properties_on_case_number", unique: true
  end

  create_table "property_check_results", force: :cascade do |t|
    t.text "api_value"
    t.integer "checklist_item_id", null: false
    t.datetime "created_at", null: false
    t.boolean "has_risk"
    t.text "manual_value"
    t.integer "property_id", null: false
    t.text "resolution_note"
    t.boolean "resolvable"
    t.integer "source_type"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["checklist_item_id"], name: "index_property_check_results_on_checklist_item_id"
    t.index ["property_id", "checklist_item_id", "user_id"], name: "idx_check_results_property_item_user", unique: true
    t.index ["property_id"], name: "index_property_check_results_on_property_id"
    t.index ["user_id"], name: "index_property_check_results_on_user_id"
  end

  create_table "property_types", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: false, null: false
    t.string "name", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_property_types_on_code", unique: true
    t.index ["enabled", "sort_order"], name: "index_property_types_on_enabled_and_sort_order"
  end

  create_table "reserve_fund_defaults", force: :cascade do |t|
    t.decimal "acquisition_tax_rate", precision: 5, scale: 4, null: false
    t.integer "area_range_max", null: false
    t.integer "area_range_min", null: false
    t.datetime "created_at", null: false
    t.integer "maintenance_fee", null: false
    t.integer "moving_cost", null: false
    t.integer "property_type_id", null: false
    t.integer "repair_cost", null: false
    t.integer "scrivener_fee", null: false
    t.datetime "updated_at", null: false
    t.index ["property_type_id", "area_range_min", "area_range_max"], name: "idx_reserve_defaults_type_area", unique: true
    t.index ["property_type_id"], name: "index_reserve_fund_defaults_on_property_type_id"
  end

  create_table "user_properties", force: :cascade do |t|
    t.datetime "analyzed_at"
    t.datetime "created_at", null: false
    t.integer "property_id", null: false
    t.integer "safety_rating"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["property_id"], name: "index_user_properties_on_property_id"
    t.index ["user_id", "property_id"], name: "index_user_properties_on_user_id_and_property_id", unique: true
    t.index ["user_id"], name: "index_user_properties_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "budget_settings", "loan_policies"
  add_foreign_key "budget_settings", "property_types"
  add_foreign_key "budget_settings", "users"
  add_foreign_key "budget_snapshots", "budget_snapshots", column: "parent_snapshot_id"
  add_foreign_key "budget_snapshots", "users"
  add_foreign_key "loan_policies", "property_types"
  add_foreign_key "property_check_results", "checklist_items"
  add_foreign_key "property_check_results", "properties"
  add_foreign_key "property_check_results", "users"
  add_foreign_key "reserve_fund_defaults", "property_types"
  add_foreign_key "user_properties", "properties"
  add_foreign_key "user_properties", "users"
end
