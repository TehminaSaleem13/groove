class RemoveExtendedProductFromShopifyCred < ActiveRecord::Migration[5.1]
  def up
    remove_column :shipping_easy_credentials, :includes_product if column_exists? :shipping_easy_credentials, :includes_product
  end

  def down
    add_column :shipping_easy_credentials, :includes_product, :boolean, :default => false
  end
end
