class AddColumnMgRestProductSkuToSyncOptions < ActiveRecord::Migration
  def change
    add_column :sync_options, :mg_rest_product_sku, :string
  end
end
