# frozen_string_literal: true

class CreateProductFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :product_feedbacks do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :category, null: false, default: 0
      t.string :title, null: false, limit: 200
      t.text :description, null: false
      t.integer :status, null: false, default: 0
      t.text :admin_notes
      t.integer :votes_count, default: 0

      t.timestamps
    end

    add_index :product_feedbacks, %i[user_id status]
    add_index :product_feedbacks, :category
    add_index :product_feedbacks, :status
    add_index :product_feedbacks, :created_at
  end
end
