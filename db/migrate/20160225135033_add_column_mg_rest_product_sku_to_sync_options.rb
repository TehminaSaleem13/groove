class AddColumnMgRestProductSkuToSyncOptions < ActiveRecord::Migration[5.1]
  def change
    add_column :sync_options, :mg_rest_product_sku, :string
  end
end
