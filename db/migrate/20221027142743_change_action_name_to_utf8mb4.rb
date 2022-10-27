class ChangeActionNameToUtf8mb4 < ActiveRecord::Migration[5.1]
  def change
    execute "ALTER TABLE order_activities MODIFY action LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  end
end
