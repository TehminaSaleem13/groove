# frozen_string_literal: true

class CreateRequestLogs < ActiveRecord::Migration[6.1]
  def change
    create_table :request_logs do |t|
      t.string :request_method
      t.string :request_path
      t.longtext :request_body
      t.boolean :completed, default: false
      t.float :duration # To store the time taken for the request in seconds

      t.timestamps
    end
  end
end
