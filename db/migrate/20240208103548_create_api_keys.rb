# frozen_string_literal: true

class CreateApiKeys < ActiveRecord::Migration[5.1]
  def change
    create_table :api_keys do |t|
      t.belongs_to :author, null: false
      t.string :token, null: false
      t.datetime :expires_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :api_keys, :token, unique: true
  end
end
