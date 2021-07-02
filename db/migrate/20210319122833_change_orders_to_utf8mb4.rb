class ChangeOrdersToUtf8mb4 < ActiveRecord::Migration[5.1]
  def change
    execute "ALTER TABLE orders MODIFY customer_comments VARCHAR(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  end
end
