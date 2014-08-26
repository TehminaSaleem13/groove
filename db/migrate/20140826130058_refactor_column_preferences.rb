class RefactorColumnPreferences < ActiveRecord::Migration
  def up
    remove_column :column_preferences, :shown
    remove_column :column_preferences, :order
    add_column :column_preferences, :theads, :text
  end

  def down
    add_column :column_preferences, :shown, :text
    add_column :column_preferences, :order, :text
    remove_column :column_preferences, :theads
  end
end
