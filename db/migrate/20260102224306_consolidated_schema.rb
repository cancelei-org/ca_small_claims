# Consolidated migration - combines all previous migrations
# Original migrations: 14
# Generated: 2026-01-02T22:43:06.706193
#
# This migration creates the complete schema in a single file.
# Original migration files have been archived.

class ConsolidatedSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :categories, force: :cascade do |t|
      t.boolean :active, default: true
      t.datetime :created_at, null: false
      t.text :description
      t.string :icon
      t.string :name, null: false
      t.integer :parent_id
      t.integer :position, default: 0
      t.string :slug, null: false
      t.datetime :updated_at, null: false
      t.index [ :parent_id, :position ], name: "index_categories_on_parent_id_and_position"
      t.index :parent_id, name: "index_categories_on_parent_id"
      t.index :slug, name: "index_categories_on_slug", unique: true
    end

    create_table :field_definitions, force: :cascade do |t|
      t.json :conditions, default: {}
      t.datetime :created_at, null: false
      t.string :field_type, null: false
      t.integer :form_definition_id, null: false
      t.text :help_text
      t.string :label
      t.integer :max_length
      t.integer :max_repetitions
      t.integer :min_length
      t.string :name, null: false
      t.json :options, default: []
      t.integer :page_number
      t.string :pdf_field_name, null: false
      t.string :placeholder
      t.integer :position
      t.string :repeating_group
      t.boolean :required, default: false
      t.string :section
      t.string :shared_field_key
      t.datetime :updated_at, null: false
      t.string :validation_pattern
      t.string :width, default: "full"
      t.index [ :form_definition_id, :name ], name: "index_field_definitions_on_form_definition_id_and_name", unique: true
      t.index :form_definition_id, name: "index_field_definitions_on_form_definition_id"
      t.index :pdf_field_name, name: "index_field_definitions_on_pdf_field_name"
      t.index :shared_field_key, name: "index_field_definitions_on_shared_field_key"
    end

    create_table :form_definitions, force: :cascade do |t|
      t.boolean :active, default: true
      t.string :category
      t.integer :category_id
      t.string :code, null: false
      t.datetime :created_at, null: false
      t.text :description
      t.boolean :fillable, null: false, default: true
      t.json :metadata, default: {}
      t.integer :page_count
      t.string :pdf_filename, null: false
      t.integer :position
      t.string :slug
      t.string :title, null: false
      t.datetime :updated_at, null: false
      t.index :active, name: "index_form_definitions_on_active"
      t.index :category, name: "index_form_definitions_on_category"
      t.index :category_id, name: "index_form_definitions_on_category_id"
      t.index :code, name: "index_form_definitions_on_code", unique: true
      t.index :slug, name: "index_form_definitions_on_slug", unique: true
    end

    create_table :form_feedbacks, force: :cascade do |t|
      t.text :admin_notes
      t.text :comment
      t.datetime :created_at, null: false
      t.bigint :form_definition_id, null: false
      t.string :issue_types, default: [], array: true
      t.integer :rating, null: false
      t.datetime :resolved_at
      t.bigint :resolved_by_id
      t.string :session_id
      t.string :status, null: false, default: "pending"
      t.datetime :updated_at, null: false
      t.bigint :user_id
      t.index [ :form_definition_id, :status ], name: "index_form_feedbacks_on_form_definition_id_and_status"
      t.index :form_definition_id, name: "index_form_feedbacks_on_form_definition_id"
      t.index :issue_types, name: "index_form_feedbacks_on_issue_types", using: :gin
      t.index :rating, name: "index_form_feedbacks_on_rating"
      t.index :resolved_by_id, name: "index_form_feedbacks_on_resolved_by_id"
      t.index :status, name: "index_form_feedbacks_on_status"
      t.index :user_id, name: "index_form_feedbacks_on_user_id"
    end

    create_table :friendly_id_slugs, force: :cascade do |t|
      t.datetime :created_at
      t.string :scope
      t.string :slug, null: false
      t.integer :sluggable_id, null: false
      t.string :sluggable_type, limit: 50
      t.index [ :slug, :sluggable_type, :scope ], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
      t.index [ :slug, :sluggable_type ], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
      t.index :sluggable_id, name: "index_friendly_id_slugs_on_sluggable_id"
    end

    create_table :session_submissions, force: :cascade do |t|
      t.datetime :created_at, null: false
      t.datetime :expires_at, null: false
      t.json :form_data, default: {}
      t.integer :form_definition_id, null: false
      t.string :session_id, null: false
      t.datetime :updated_at, null: false
      t.index :expires_at, name: "index_session_submissions_on_expires_at"
      t.index :form_definition_id, name: "index_session_submissions_on_form_definition_id"
      t.index [ :session_id, :form_definition_id ], name: "index_session_submissions_on_session_id_and_form_definition_id", unique: true
      t.index :session_id, name: "index_session_submissions_on_session_id"
    end

    create_table :submissions, force: :cascade do |t|
      t.datetime :completed_at
      t.datetime :created_at, null: false
      t.json :form_data, default: {}
      t.integer :form_definition_id, null: false
      t.datetime :pdf_generated_at
      t.string :session_id
      t.string :status, default: "draft"
      t.datetime :updated_at, null: false
      t.integer :user_id
      t.integer :workflow_id
      t.string :workflow_session_id
      t.integer :workflow_step_position
      t.index :form_definition_id, name: "index_submissions_on_form_definition_id"
      t.index :session_id, name: "index_submissions_on_session_id"
      t.index :status, name: "index_submissions_on_status"
      t.index [ :user_id, :status ], name: "index_submissions_on_user_id_and_status"
      t.index :user_id, name: "index_submissions_on_user_id"
      t.index :workflow_id, name: "index_submissions_on_workflow_id"
      t.index :workflow_session_id, name: "index_submissions_on_workflow_session_id"
    end

    create_table :users, force: :cascade do |t|
      t.text :address
      t.boolean :admin, null: false, default: false
      t.string :city
      t.datetime :created_at, null: false
      t.date :date_of_birth
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :full_name
      t.boolean :guest
      t.string :guest_token
      t.string :phone
      t.jsonb :preferences, default: {}
      t.datetime :remember_created_at
      t.datetime :reset_password_sent_at
      t.string :reset_password_token
      t.string :state, default: "CA"
      t.datetime :updated_at, null: false
      t.string :zip_code
      t.index :admin, name: "index_users_on_admin"
      t.index :email, name: "index_users_on_email", unique: true
      t.index :reset_password_token, name: "index_users_on_reset_password_token", unique: true
    end

    create_table :workflow_steps, force: :cascade do |t|
      t.json :conditions, default: {}
      t.datetime :created_at, null: false
      t.json :data_mappings, default: {}
      t.integer :form_definition_id, null: false
      t.text :instructions
      t.string :name
      t.integer :position, null: false
      t.boolean :repeatable, default: false
      t.boolean :required, default: true
      t.datetime :updated_at, null: false
      t.integer :workflow_id, null: false
      t.index :form_definition_id, name: "index_workflow_steps_on_form_definition_id"
      t.index [ :workflow_id, :position ], name: "index_workflow_steps_on_workflow_id_and_position", unique: true
      t.index :workflow_id, name: "index_workflow_steps_on_workflow_id"
    end

    create_table :workflows, force: :cascade do |t|
      t.boolean :active, default: true
      t.string :category
      t.integer :category_id
      t.datetime :created_at, null: false
      t.text :description
      t.string :name, null: false
      t.integer :position
      t.string :slug, null: false
      t.datetime :updated_at, null: false
      t.index :active, name: "index_workflows_on_active"
      t.index :category, name: "index_workflows_on_category"
      t.index :category_id, name: "index_workflows_on_category_id"
      t.index :slug, name: "index_workflows_on_slug", unique: true
    end

    add_foreign_key :categories, :categories, column: :parent_id
    add_foreign_key :field_definitions, :form_definitions, column: :form_definition_id
    add_foreign_key :form_definitions, :categories, column: :categorie_id
    add_foreign_key :form_feedbacks, :form_definitions, column: :form_definition_id
    add_foreign_key :form_feedbacks, :users, column: :user_id
    add_foreign_key :form_feedbacks, :users, column: :resolved_by_id
    add_foreign_key :session_submissions, :form_definitions, column: :form_definition_id
    add_foreign_key :submissions, :form_definitions, column: :form_definition_id
    add_foreign_key :submissions, :users, column: :user_id
    add_foreign_key :submissions, :workflows, column: :workflow_id
    add_foreign_key :workflow_steps, :form_definitions, column: :form_definition_id
    add_foreign_key :workflow_steps, :workflows, column: :workflow_id
    add_foreign_key :workflows, :categories, column: :categorie_id
  end
end
