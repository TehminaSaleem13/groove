class UpdateOrderItemColumnsToSupportsEmojis < ActiveRecord::Migration[5.1]
  def up
    execute "ALTER TABLE order_items MODIFY name LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  end

  def down; end
end
