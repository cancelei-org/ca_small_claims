class AddRoleToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :users, :role, :string, default: "user", null: false
    add_index :users, :role, algorithm: :concurrently
  end
end
