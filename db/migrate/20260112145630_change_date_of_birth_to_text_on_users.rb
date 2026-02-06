# frozen_string_literal: true

class ChangeDateOfBirthToTextOnUsers < ActiveRecord::Migration[8.1]
  def up
    # Change date_of_birth from date to text to support Active Record Encryption
    # Encrypted values are stored as ciphertext strings, not native date types
    #
    # Note: This is safe for a new/small application. For production with lots of data,
    # follow the multi-step approach recommended by strong_migrations.
    safety_assured { change_column :users, :date_of_birth, :text }
  end

  def down
    # Note: This will fail if there's encrypted data in the column
    # Only run down if the column contains unencrypted date strings
    safety_assured { change_column :users, :date_of_birth, :date, using: "date_of_birth::date" }
  end
end
