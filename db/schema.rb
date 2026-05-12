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

ActiveRecord::Schema[8.1].define(version: 2026_05_12_230000) do
  create_table "acquisition_tax_rate_audit_logs", force: :cascade do |t|
    t.integer "acquisition_tax_rate_id"
    t.string "action", null: false
    t.text "changes_json", null: false
    t.datetime "created_at", null: false
    t.integer "user_id", null: false
    t.index ["acquisition_tax_rate_id", "created_at"], name: "index_acq_tax_rate_audit_logs_on_rate_and_time"
    t.index ["user_id", "created_at"], name: "index_acq_tax_rate_audit_logs_on_user_and_time"
    t.index ["user_id"], name: "index_acquisition_tax_rate_audit_logs_on_user_id"
  end

  create_table "acquisition_tax_rates", force: :cascade do |t|
    t.boolean "area_over_85"
    t.datetime "created_at", null: false
    t.string "household_tier", null: false
    t.integer "price_bucket_max_manwon"
    t.integer "price_bucket_min_manwon", default: 0, null: false
    t.integer "property_type_id", null: false
    t.boolean "regulated_region"
    t.decimal "total_rate", precision: 5, scale: 4, null: false
    t.datetime "updated_at", null: false
    t.index ["property_type_id", "household_tier", "regulated_region", "area_over_85"], name: "index_acquisition_tax_rates_on_lookup"
    t.index ["property_type_id"], name: "index_acquisition_tax_rates_on_property_type_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "api_credentials", force: :cascade do |t|
    t.string "api_key"
    t.string "api_secret"
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "last_verified_at"
    t.string "provider_name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "provider_name"], name: "index_api_credentials_on_user_id_and_provider_name", unique: true
    t.index ["user_id"], name: "index_api_credentials_on_user_id"
  end

  create_table "auction_schedules", force: :cascade do |t|
    t.date "bid_end_date"
    t.date "bid_start_date"
    t.datetime "created_at", null: false
    t.bigint "min_price"
    t.string "place"
    t.integer "property_id", null: false
    t.string "result_code"
    t.bigint "sale_amount"
    t.date "schedule_date"
    t.string "schedule_time"
    t.string "schedule_type"
    t.datetime "updated_at", null: false
    t.index ["property_id", "schedule_date"], name: "index_auction_schedules_on_property_id_and_schedule_date"
    t.index ["property_id"], name: "index_auction_schedules_on_property_id"
  end

  create_table "budget_settings", force: :cascade do |t|
    t.integer "acquisition_tax"
    t.boolean "acquisition_tax_auto", default: true, null: false
    t.boolean "acquisition_tax_precise_mode", default: false, null: false
    t.integer "area_range_max"
    t.integer "area_range_min"
    t.integer "available_cash"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "household_tier", default: "homeless", null: false
    t.integer "loan_policy_id"
    t.decimal "loan_ratio", precision: 3, scale: 2
    t.integer "maintenance_fee"
    t.integer "max_bid_amount"
    t.integer "moving_cost"
    t.integer "property_type_id"
    t.string "region", default: "제주특별자치도"
    t.integer "repair_cost"
    t.integer "scrivener_fee"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["loan_policy_id"], name: "index_budget_settings_on_loan_policy_id"
    t.index ["property_type_id"], name: "index_budget_settings_on_property_type_id"
    t.index ["user_id"], name: "index_budget_settings_on_user_id", unique: true
  end

  create_table "eviction_simulations", force: :cascade do |t|
    t.json "answers"
    t.boolean "completed", default: false, null: false
    t.datetime "created_at", null: false
    t.string "difficulty_level"
    t.string "occupant_type"
    t.integer "property_id"
    t.json "result_path"
    t.string "session_id"
    t.datetime "updated_at", null: false
    t.index ["property_id"], name: "idx_eviction_simulations_one_per_property", unique: true, where: "property_id IS NOT NULL"
    t.index ["property_id"], name: "index_eviction_simulations_on_property_id"
    t.index ["session_id"], name: "index_eviction_simulations_on_session_id"
  end

  create_table "eviction_simulator_questions", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "difficulty_impact"
    t.string "f02_field_mapping"
    t.text "help_text"
    t.string "no_next_code"
    t.string "occupant_type"
    t.integer "phase", default: 0, null: false
    t.text "question", null: false
    t.string "step_code", null: false
    t.datetime "updated_at", null: false
    t.string "yes_next_code"
    t.index ["code"], name: "index_eviction_simulator_questions_on_code", unique: true
    t.index ["occupant_type"], name: "index_eviction_simulator_questions_on_occupant_type"
    t.index ["step_code"], name: "index_eviction_simulator_questions_on_step_code"
  end

  create_table "eviction_steps", force: :cascade do |t|
    t.json "action_steps"
    t.json "branch_codes"
    t.string "code", null: false
    t.text "completion_condition"
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.string "estimated_cost"
    t.string "estimated_duration"
    t.text "failure_condition"
    t.json "legal_basis"
    t.string "name", null: false
    t.string "next_step_code"
    t.string "occupant_type"
    t.integer "position", default: 0, null: false
    t.text "problem_summary"
    t.json "required_documents"
    t.string "return_step_code"
    t.text "root_cause"
    t.integer "step_type", default: 0, null: false
    t.string "trigger_step_code"
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_eviction_steps_on_code", unique: true
    t.index ["occupant_type"], name: "index_eviction_steps_on_occupant_type"
    t.index ["step_type", "position"], name: "index_eviction_steps_on_step_type_and_position"
  end

  create_table "identities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.boolean "email_verified"
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["provider", "uid"], name: "index_identities_on_provider_and_uid", unique: true
    t.index ["user_id", "provider"], name: "index_identities_on_user_id_and_provider"
    t.index ["user_id"], name: "index_identities_on_user_id"
  end

  create_table "inspection_items", force: :cascade do |t|
    t.string "answer_type"
    t.json "applicable_types"
    t.string "category", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "data_source_name"
    t.json "depends_on"
    t.text "description"
    t.json "logic"
    t.string "merged_from"
    t.string "priority", default: "상", null: false
    t.text "question", null: false
    t.integer "tab", null: false
    t.integer "tab_position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.boolean "yes_means_safe", default: true, null: false
    t.index ["code"], name: "index_inspection_items_on_code", unique: true
    t.index ["tab", "tab_position"], name: "index_inspection_items_on_tab_and_tab_position"
  end

  create_table "inspection_result_versions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "evidence"
    t.boolean "has_risk"
    t.integer "inspection_result_id", null: false
    t.text "resolution_note"
    t.datetime "snapshotted_at", null: false
    t.integer "source_type"
    t.datetime "updated_at", null: false
    t.integer "version_number", null: false
    t.index ["inspection_result_id", "version_number"], name: "idx_inspection_result_versions_unique", unique: true
    t.index ["inspection_result_id"], name: "index_inspection_result_versions_on_inspection_result_id"
  end

  create_table "inspection_results", force: :cascade do |t|
    t.text "auto_value"
    t.datetime "created_at", null: false
    t.json "evidence"
    t.boolean "has_risk"
    t.integer "inspection_item_id", null: false
    t.text "manual_value"
    t.integer "property_id", null: false
    t.text "resolution_note"
    t.boolean "resolvable"
    t.integer "source_type"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["inspection_item_id"], name: "index_inspection_results_on_inspection_item_id"
    t.index ["property_id", "inspection_item_id", "user_id"], name: "idx_inspection_results_unique", unique: true
    t.index ["property_id"], name: "index_inspection_results_on_property_id"
    t.index ["user_id"], name: "index_inspection_results_on_user_id"
  end

  create_table "llm_analysis_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.datetime "executed_at"
    t.string "model"
    t.integer "property_id", null: false
    t.string "provider"
    t.text "response_json"
    t.integer "status", default: 0, null: false
    t.text "system_prompt", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.text "user_prompt", null: false
    t.index ["property_id", "status"], name: "index_llm_analysis_logs_on_property_id_and_status"
    t.index ["property_id"], name: "index_llm_analysis_logs_on_property_id"
    t.index ["status"], name: "index_llm_analysis_logs_on_status"
    t.index ["user_id"], name: "index_llm_analysis_logs_on_user_id"
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
    t.decimal "regulated_loan_ratio", precision: 3, scale: 2, null: false
    t.string "source_url"
    t.datetime "updated_at", null: false
    t.index ["property_type_id", "enabled"], name: "index_loan_policies_on_property_type_id_and_enabled"
    t.index ["property_type_id"], name: "index_loan_policies_on_property_type_id"
  end

  create_table "properties", force: :cascade do |t|
    t.string "address"
    t.bigint "appraisal_price"
    t.string "building_detail"
    t.string "building_name"
    t.string "building_structure"
    t.string "case_number", null: false
    t.string "case_type"
    t.bigint "claim_amount"
    t.string "court_code"
    t.string "court_name"
    t.datetime "created_at", null: false
    t.string "dong"
    t.decimal "exclusive_area"
    t.integer "failed_bid_count", default: 0
    t.integer "interest_count", default: 0
    t.string "land_category"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.bigint "min_bid_price"
    t.integer "property_count", default: 1, null: false
    t.string "property_type"
    t.string "property_usage_code"
    t.text "remarks"
    t.string "sido"
    t.string "sigungu"
    t.string "special_conditions_code"
    t.string "status"
    t.datetime "updated_at", null: false
    t.integer "view_count", default: 0
    t.index ["case_number"], name: "index_properties_on_case_number", unique: true
    t.index ["property_type"], name: "index_properties_on_property_type"
    t.index ["sido", "sigungu", "dong"], name: "idx_properties_location"
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

  create_table "rights_analysis_reports", force: :cascade do |t|
    t.datetime "analyzed_at", null: false
    t.integer "assumed_amount", default: 0, null: false
    t.date "base_right_date"
    t.string "base_right_holder"
    t.string "base_right_type"
    t.datetime "created_at", null: false
    t.text "opportunity_reason"
    t.string "opportunity_type"
    t.integer "property_id", null: false
    t.json "report_data"
    t.boolean "source_doc_reviewed", default: false, null: false
    t.integer "total_risk_amount", default: 0, null: false
    t.datetime "updated_at", null: false
    t.datetime "user_confirmed_at"
    t.integer "user_id", null: false
    t.integer "verdict", default: 0, null: false
    t.text "verdict_summary"
    t.index ["property_id"], name: "index_rights_analysis_reports_on_property_id"
    t.index ["user_id", "property_id"], name: "idx_rights_reports_user_property", unique: true
    t.index ["user_id"], name: "index_rights_analysis_reports_on_user_id"
  end

  create_table "search_results", force: :cascade do |t|
    t.string "address"
    t.integer "appraisal_price"
    t.string "auction_date"
    t.string "case_number", null: false
    t.string "court_code"
    t.string "court_name"
    t.datetime "created_at", null: false
    t.integer "failed_bid_count"
    t.integer "min_bid_price"
    t.integer "property_count", default: 1, null: false
    t.string "property_type"
    t.string "remarks"
    t.string "status"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "case_number"], name: "index_search_results_on_user_id_and_case_number", unique: true
    t.index ["user_id"], name: "index_search_results_on_user_id"
  end

  create_table "user_properties", force: :cascade do |t|
    t.datetime "analyzed_at"
    t.datetime "created_at", null: false
    t.boolean "favorite", default: false, null: false
    t.date "inspection_visited_on"
    t.text "notes"
    t.integer "property_id", null: false
    t.integer "safety_rating"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["property_id"], name: "index_user_properties_on_property_id"
    t.index ["user_id", "favorite", "created_at"], name: "index_user_properties_on_user_favorite_created"
    t.index ["user_id", "property_id"], name: "index_user_properties_on_user_id_and_property_id", unique: true
    t.index ["user_id"], name: "index_user_properties_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.string "avatar_url"
    t.boolean "beginner_mode", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.boolean "guest", default: true, null: false
    t.string "guest_token"
    t.integer "last_search_api_total_count"
    t.datetime "last_seen_at"
    t.string "name"
    t.datetime "terms_accepted_at"
    t.datetime "updated_at", null: false
    t.index ["admin"], name: "index_users_on_admin_when_true", where: "admin = 1"
    t.index ["email"], name: "index_users_on_email_when_account", unique: true, where: "guest = 0 AND email IS NOT NULL"
    t.index ["guest", "last_seen_at"], name: "index_users_on_guest_and_last_seen_at"
    t.index ["guest_token"], name: "index_users_on_guest_token", unique: true
  end

  add_foreign_key "acquisition_tax_rate_audit_logs", "users"
  add_foreign_key "acquisition_tax_rates", "property_types"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_credentials", "users"
  add_foreign_key "auction_schedules", "properties"
  add_foreign_key "budget_settings", "loan_policies"
  add_foreign_key "budget_settings", "property_types"
  add_foreign_key "budget_settings", "users"
  add_foreign_key "eviction_simulations", "properties"
  add_foreign_key "identities", "users"
  add_foreign_key "inspection_result_versions", "inspection_results"
  add_foreign_key "inspection_results", "inspection_items"
  add_foreign_key "inspection_results", "properties"
  add_foreign_key "inspection_results", "users"
  add_foreign_key "llm_analysis_logs", "properties"
  add_foreign_key "llm_analysis_logs", "users"
  add_foreign_key "loan_policies", "property_types"
  add_foreign_key "reserve_fund_defaults", "property_types"
  add_foreign_key "rights_analysis_reports", "properties"
  add_foreign_key "rights_analysis_reports", "users"
  add_foreign_key "search_results", "users"
  add_foreign_key "user_properties", "properties"
  add_foreign_key "user_properties", "users"
end
