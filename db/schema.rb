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

ActiveRecord::Schema[8.1].define(version: 2026_01_26_210006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "alert_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event", null: false
    t.jsonb "payload", default: {}
    t.string "severity", null: false
    t.datetime "updated_at", null: false
  end

  create_table "audit_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "details"
    t.string "event"
    t.string "ip_address"
    t.integer "target_id"
    t.string "target_type"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "icon"
    t.string "name", null: false
    t.integer "parent_id"
    t.integer "position", default: 0
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id", "position"], name: "index_categories_on_parent_id_and_position"
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "courthouses", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "address", null: false
    t.string "city", null: false
    t.string "county", null: false
    t.string "court_type", default: "small_claims"
    t.datetime "created_at", null: false
    t.string "hours"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.string "name", null: false
    t.text "notes"
    t.string "phone"
    t.datetime "updated_at", null: false
    t.string "website_url"
    t.string "zip", null: false
    t.index ["active"], name: "index_courthouses_on_active"
    t.index ["city"], name: "index_courthouses_on_city"
    t.index ["county"], name: "index_courthouses_on_county"
    t.index ["latitude", "longitude"], name: "index_courthouses_on_coordinates"
    t.index ["zip"], name: "index_courthouses_on_zip"
  end

  create_table "field_definitions", force: :cascade do |t|
    t.json "conditions", default: {}
    t.datetime "created_at", null: false
    t.string "field_type", null: false
    t.integer "form_definition_id", null: false
    t.text "help_text"
    t.string "label"
    t.integer "max_length"
    t.integer "max_repetitions"
    t.integer "min_length"
    t.string "name", null: false
    t.json "options", default: []
    t.integer "page_number"
    t.string "pdf_field_name", null: false
    t.string "placeholder"
    t.integer "position"
    t.string "repeating_group"
    t.boolean "required", default: false
    t.string "section"
    t.string "shared_field_key"
    t.datetime "updated_at", null: false
    t.string "validation_pattern"
    t.string "width", default: "full"
    t.index ["form_definition_id", "name"], name: "index_field_definitions_on_form_definition_id_and_name", unique: true
    t.index ["form_definition_id"], name: "index_field_definitions_on_form_definition_id"
    t.index ["pdf_field_name"], name: "index_field_definitions_on_pdf_field_name"
    t.index ["shared_field_key"], name: "index_field_definitions_on_shared_field_key"
  end

  create_table "form_definitions", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "category"
    t.integer "category_id"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "fillable", default: true, null: false
    t.json "metadata", default: {}
    t.integer "page_count"
    t.string "pdf_filename", null: false
    t.integer "position"
    t.string "slug"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_form_definitions_on_active"
    t.index ["category"], name: "index_form_definitions_on_category"
    t.index ["category_id"], name: "index_form_definitions_on_category_id"
    t.index ["code"], name: "index_form_definitions_on_code", unique: true
    t.index ["slug"], name: "index_form_definitions_on_slug", unique: true
  end

  create_table "form_feedbacks", force: :cascade do |t|
    t.text "admin_notes"
    t.text "comment"
    t.datetime "created_at", null: false
    t.bigint "form_definition_id", null: false
    t.string "issue_types", default: [], array: true
    t.string "priority", default: "medium", null: false
    t.integer "rating", null: false
    t.datetime "resolved_at"
    t.bigint "resolved_by_id"
    t.string "session_id"
    t.string "status", default: "open", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["form_definition_id", "status"], name: "index_form_feedbacks_on_form_definition_id_and_status"
    t.index ["form_definition_id"], name: "index_form_feedbacks_on_form_definition_id"
    t.index ["issue_types"], name: "index_form_feedbacks_on_issue_types", using: :gin
    t.index ["priority"], name: "index_form_feedbacks_on_priority"
    t.index ["rating"], name: "index_form_feedbacks_on_rating"
    t.index ["resolved_by_id"], name: "index_form_feedbacks_on_resolved_by_id"
    t.index ["status", "priority"], name: "index_form_feedbacks_on_status_and_priority"
    t.index ["status"], name: "index_form_feedbacks_on_status"
    t.index ["user_id"], name: "index_form_feedbacks_on_user_id"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.datetime "created_at"
    t.string "scope"
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_id"
  end

  create_table "impersonation_logs", force: :cascade do |t|
    t.bigint "admin_id", null: false
    t.datetime "created_at", null: false
    t.datetime "ended_at"
    t.string "ip_address"
    t.string "reason"
    t.datetime "started_at", null: false
    t.bigint "target_user_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["admin_id", "started_at"], name: "index_impersonation_logs_on_admin_id_and_started_at"
    t.index ["admin_id"], name: "index_impersonation_logs_on_admin_id"
    t.index ["started_at"], name: "index_impersonation_logs_on_started_at"
    t.index ["target_user_id"], name: "index_impersonation_logs_on_target_user_id"
  end

  create_table "notification_preferences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "email_deadline_reminders", default: true, null: false
    t.boolean "email_fee_waiver_status", default: true, null: false
    t.boolean "email_form_download", default: true, null: false
    t.boolean "email_form_submission", default: true, null: false
    t.boolean "email_marketing", default: false, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_notification_preferences_on_user_id", unique: true
  end

  create_table "product_feedback_votes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_feedback_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["product_feedback_id"], name: "index_product_feedback_votes_on_product_feedback_id"
    t.index ["user_id", "product_feedback_id"], name: "idx_on_user_id_product_feedback_id_6c0e8e476d", unique: true
    t.index ["user_id"], name: "index_product_feedback_votes_on_user_id"
  end

  create_table "product_feedbacks", force: :cascade do |t|
    t.text "admin_notes"
    t.integer "category", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.integer "status", default: 0, null: false
    t.string "title", limit: 200, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "votes_count", default: 0
    t.index ["category"], name: "index_product_feedbacks_on_category"
    t.index ["created_at"], name: "index_product_feedbacks_on_created_at"
    t.index ["status"], name: "index_product_feedbacks_on_status"
    t.index ["user_id", "status"], name: "index_product_feedbacks_on_user_id_and_status"
    t.index ["user_id"], name: "index_product_feedbacks_on_user_id"
  end

  create_table "session_submissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.json "form_data", default: {}
    t.integer "form_definition_id", null: false
    t.string "session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_session_submissions_on_expires_at"
    t.index ["form_definition_id"], name: "index_session_submissions_on_form_definition_id"
    t.index ["session_id", "expires_at"], name: "index_session_submissions_on_session_and_expires"
    t.index ["session_id", "form_definition_id"], name: "index_session_submissions_on_session_id_and_form_definition_id", unique: true
    t.index ["session_id"], name: "index_session_submissions_on_session_id"
  end

  create_table "submissions", force: :cascade do |t|
    t.text "admin_notes"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.json "form_data", default: {}
    t.integer "form_definition_id", null: false
    t.datetime "pdf_generated_at"
    t.string "session_id"
    t.string "status", default: "draft"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.integer "workflow_id"
    t.string "workflow_session_id"
    t.integer "workflow_step_position"
    t.index ["form_definition_id", "status"], name: "index_submissions_on_form_definition_and_status"
    t.index ["form_definition_id"], name: "index_submissions_on_form_definition_id"
    t.index ["session_id"], name: "index_submissions_on_session_id"
    t.index ["status"], name: "index_submissions_on_status"
    t.index ["user_id", "status", "created_at"], name: "index_submissions_on_user_status_created"
    t.index ["user_id", "status"], name: "index_submissions_on_user_id_and_status"
    t.index ["user_id"], name: "index_submissions_on_user_id"
    t.index ["workflow_id"], name: "index_submissions_on_workflow_id"
    t.index ["workflow_session_id"], name: "index_submissions_on_workflow_session_id"
  end

  create_table "users", force: :cascade do |t|
    t.text "address"
    t.boolean "admin", default: false, null: false
    t.string "city"
    t.datetime "created_at", null: false
    t.text "date_of_birth"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "full_name"
    t.boolean "guest"
    t.string "guest_token"
    t.string "phone"
    t.jsonb "preferences", default: {}
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "user", null: false
    t.string "state", default: "CA"
    t.datetime "updated_at", null: false
    t.string "zip_code"
    t.index ["admin"], name: "index_users_on_admin"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "workflow_steps", force: :cascade do |t|
    t.json "conditions", default: {}
    t.datetime "created_at", null: false
    t.json "data_mappings", default: {}
    t.integer "form_definition_id", null: false
    t.text "instructions"
    t.string "name"
    t.integer "position", null: false
    t.boolean "repeatable", default: false
    t.boolean "required", default: true
    t.datetime "updated_at", null: false
    t.integer "workflow_id", null: false
    t.index ["form_definition_id"], name: "index_workflow_steps_on_form_definition_id"
    t.index ["workflow_id", "position"], name: "index_workflow_steps_on_workflow_id_and_position", unique: true
    t.index ["workflow_id"], name: "index_workflow_steps_on_workflow_id"
  end

  create_table "workflows", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "category"
    t.integer "category_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "position"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_workflows_on_active"
    t.index ["category"], name: "index_workflows_on_category"
    t.index ["category_id"], name: "index_workflows_on_category_id"
    t.index ["slug"], name: "index_workflows_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "field_definitions", "form_definitions"
  add_foreign_key "form_definitions", "categories"
  add_foreign_key "form_feedbacks", "form_definitions"
  add_foreign_key "form_feedbacks", "users"
  add_foreign_key "form_feedbacks", "users", column: "resolved_by_id"
  add_foreign_key "impersonation_logs", "users", column: "admin_id"
  add_foreign_key "impersonation_logs", "users", column: "target_user_id"
  add_foreign_key "notification_preferences", "users"
  add_foreign_key "product_feedback_votes", "product_feedbacks"
  add_foreign_key "product_feedback_votes", "users"
  add_foreign_key "product_feedbacks", "users"
  add_foreign_key "session_submissions", "form_definitions"
  add_foreign_key "submissions", "form_definitions"
  add_foreign_key "submissions", "users"
  add_foreign_key "submissions", "workflows"
  add_foreign_key "workflow_steps", "form_definitions"
  add_foreign_key "workflow_steps", "workflows"
  add_foreign_key "workflows", "categories"
end
