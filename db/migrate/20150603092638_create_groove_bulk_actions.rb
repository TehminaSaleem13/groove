class CreateGrooveBulkActions < ActiveRecord::Migration
  def change
    create_table :groove_bulk_actions do |t|
      t.string  :identifier, :null => false
      t.string  :activity, :null => false
      t.integer :total, :default => 0
      t.integer :completed, :default => 0
      t.string  :status,  :default => 'scheduled'
      t.string  :current
      t.string  :messages
      t.boolean :cancel, :default => false
      t.timestamps
    end
  end
end
