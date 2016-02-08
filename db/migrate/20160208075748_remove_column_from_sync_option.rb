class RemoveColumnFromSyncOption < ActiveRecord::Migration
  def up
    remove_column :sync_options, :shopify_product_sku
  end

  def down
    add_column :sync_options, :shopify_product_sku, :string
  end
end
