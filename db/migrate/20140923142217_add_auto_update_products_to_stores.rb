class AddAutoUpdateProductsToStores < ActiveRecord::Migration
  def change
    add_column :stores, :auto_update_products, :boolean, :default => false
  end
end
