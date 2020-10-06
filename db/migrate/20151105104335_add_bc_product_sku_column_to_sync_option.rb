class AddBcProductSkuColumnToSyncOption < ActiveRecord::Migration[5.1]
  def change
    add_column :sync_options, :bc_product_sku, :string
  end
end
