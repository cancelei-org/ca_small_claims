class AddProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :city, :string
    add_column :users, :state, :string, default: "CA"
    add_column :users, :zip_code, :string
    add_column :users, :date_of_birth, :date
  end
end
