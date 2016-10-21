class AddColumnToShopify < ActiveRecord::Migration
  def change
  	add_column :shopify_credentials, :last_imported_at, :datetime
  end
end
