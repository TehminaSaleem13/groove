class AddBcProductSkuColumnToSyncOption < ActiveRecord::Migration
  def change
    add_column :sync_options, :bc_product_sku, :string
  end
end
