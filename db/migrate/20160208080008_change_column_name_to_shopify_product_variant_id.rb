class ChangeColumnNameToShopifyProductVariantId < ActiveRecord::Migration[5.1]
  def up
  	rename_column :sync_options, :shopify_product_id, :shopify_product_variant_id
  end

  def down
  	rename_column :sync_options, :shopify_product_variant_id, :shopify_product_id
  end
end
