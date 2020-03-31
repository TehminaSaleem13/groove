class RemoveExtendedProductFromShopifyCred < ActiveRecord::Migration
  def up
    remove_column :shipping_easy_credentials, :includes_product
  end

  def down
    add_column :shipping_easy_credentials, :includes_product, :boolean, :default => false
  end
end
