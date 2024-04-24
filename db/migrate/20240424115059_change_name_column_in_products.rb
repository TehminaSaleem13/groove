class ChangeNameColumnInProducts < ActiveRecord::Migration[5.1]
  def up
    execute "ALTER TABLE products MODIFY name LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  end

  def down
    execute "ALTER TABLE products MODIFY name VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  end
end
