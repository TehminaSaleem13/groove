class CreateColumnPreferences < ActiveRecord::Migration
  def change
    create_table :column_preferences do |t|
      t.references :user
      t.string :identifier
      t.text :shown
      t.text :order

      t.timestamps
    end
    add_index :column_preferences, :user_id
  end
end
