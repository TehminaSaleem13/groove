class ChangeOrdersToUtf8mb4 < ActiveRecord::Migration[5.1]
  def up
    execute "ALTER TABLE orders CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_bin"
    execute "ALTER TABLE orders MODIFY customer_comments VARCHAR(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin"
  end
  
  def down
    execute "ALTER TABLE orders CONVERT TO CHARACTER SET utf8 COLLATE utf8_bin"
    execute "ALTER TABLE orders MODIFY customer_comments VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_bin"
  end
end
