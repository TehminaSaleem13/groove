class AddSyncWithTeapplixAndTeapplixProductSkuColumnsToSyncOptions < ActiveRecord::Migration[5.1]
  def change
    add_column :sync_options, :sync_with_teapplix, :boolean, default: false
    add_column :sync_options, :teapplix_product_sku, :string
  end
end
