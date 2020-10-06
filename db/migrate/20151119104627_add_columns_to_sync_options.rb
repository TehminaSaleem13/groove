class AddColumnsToSyncOptions < ActiveRecord::Migration[5.1]
  def change
    add_column :sync_options, :sync_with_mg_rest, :boolean
    add_column :sync_options, :mg_rest_product_id, :integer
  end
end
