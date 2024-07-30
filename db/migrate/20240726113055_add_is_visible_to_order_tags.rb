class AddIsVisibleToOrderTags < ActiveRecord::Migration[5.1]
  def change
    add_column :order_tags, :isVisible, :boolean, default: true
  end
end
