class AddAdminNotesToSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :submissions, :admin_notes, :text
  end
end
