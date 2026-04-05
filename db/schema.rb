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

ActiveRecord::Schema[8.1].define(version: 2026_04_05_070618) do
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
  add_foreign_key "loan_policies", "property_types"
  add_foreign_key "reserve_fund_defaults", "property_types"
end
