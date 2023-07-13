class ChangeAhoyEventToUtf8mb4 < ActiveRecord::Migration[5.1]
  def up
    change_column :ahoy_events, :properties, :text
    execute "ALTER TABLE ahoy_events MODIFY properties LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  end

  def down
  	change_column :ahoy_events, :properties, :string
  end
end
