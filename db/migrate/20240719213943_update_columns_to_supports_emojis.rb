class UpdateColumnsToSupportsEmojis < ActiveRecord::Migration[5.1]
  def up
    execute "ALTER TABLE shipstation_label_data MODIFY content LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    execute "ALTER TABLE products MODIFY name LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    execute "ALTER TABLE orders MODIFY firstname VARCHAR(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    execute "ALTER TABLE orders MODIFY lastname VARCHAR(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    execute "ALTER TABLE orders MODIFY city VARCHAR(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    execute "ALTER TABLE origin_stores MODIFY recent_order_details VARCHAR(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    execute "ALTER TABLE ahoy_events MODIFY properties LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    execute "ALTER TABLE groove_bulk_actions MODIFY current VARCHAR(5000) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    execute "ALTER TABLE products MODIFY packing_instructions VARCHAR(5000) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    execute "ALTER TABLE order_activities MODIFY action LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    execute "ALTER TABLE product_activities MODIFY action LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    execute "ALTER TABLE orders MODIFY customer_comments LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  end

  def down; end
end
