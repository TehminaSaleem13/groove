class ChangeDataTypeInSyncOptions < ActiveRecord::Migration
  def up
  	change_column :sync_options, :shopify_product_id, :string
  end

  def down
  	change_column :sync_options, :shopify_product_id, :integer
  end
end
