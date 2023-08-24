class ChangeColumnTypeOfOrder < ActiveRecord::Migration[5.1]
  def change
    execute "ALTER TABLE orders MODIFY firstname VARCHAR(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    execute "ALTER TABLE orders MODIFY lastname VARCHAR(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    execute "ALTER TABLE orders MODIFY city VARCHAR(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    execute "ALTER TABLE orders MODIFY ss_label_data LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    execute "ALTER TABLE origin_stores MODIFY recent_order_details VARCHAR(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  end
end
