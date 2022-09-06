class CreateEventLogs < ActiveRecord::Migration[5.1]
  def change
    create_table :event_logs do |t|
      t.longtext :data
      t.text :message
      t.integer :user_id

      t.timestamps
    end
    add_index :event_logs, :user_id
  end
end
