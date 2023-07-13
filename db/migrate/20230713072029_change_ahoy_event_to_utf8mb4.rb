class ChangeAhoyEventToUtf8mb4 < ActiveRecord::Migration[5.1]
  def change
    execute "ALTER TABLE ahoy_events MODIFY properties VARCHAR(10000) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  end
end
