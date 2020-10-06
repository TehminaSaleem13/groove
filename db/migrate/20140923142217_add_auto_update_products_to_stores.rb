class AddAutoUpdateProductsToStores < ActiveRecord::Migration[5.1]
  def change
    add_column :stores, :auto_update_products, :boolean, :default => false
  end
end
