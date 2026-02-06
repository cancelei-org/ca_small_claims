class AddFillableToFormDefinitions < ActiveRecord::Migration[8.1]
  def change
    add_column :form_definitions, :fillable, :boolean, default: true, null: false
  end
end
