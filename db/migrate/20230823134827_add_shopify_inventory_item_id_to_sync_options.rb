class AddShopifyInventoryItemIdToSyncOptions < ActiveRecord::Migration[5.1]
  def change
    add_column :sync_options, :shopify_inventory_item_id, :string
  end
end
