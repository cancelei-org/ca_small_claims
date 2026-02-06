class AddAdminToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :users, :admin, :boolean, default: false, null: false
    add_index :users, :admin, algorithm: :concurrently
  end
end
