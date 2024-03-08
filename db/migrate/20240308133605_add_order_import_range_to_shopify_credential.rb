class AddOrderImportRangeToShopifyCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shopify_credentials, :order_import_range_days, :integer, default: 30
  end
end
