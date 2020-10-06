class ChangeColumnStoreProductIdToShopify < ActiveRecord::Migration[5.1]
  def up
    change_column :products, :store_product_id, :string, :null => true
  end

  def down
    change_column :products, :store_product_id, :string, :null => false
  end
end
