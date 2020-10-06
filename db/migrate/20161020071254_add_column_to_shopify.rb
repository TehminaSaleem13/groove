class AddColumnToShopify < ActiveRecord::Migration[5.1]
  def change
  	add_column :shopify_credentials, :last_imported_at, :datetime
  end
end
