class AddImportOnlyTrackingToShopifyCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shopify_credentials, :import_fulfilled_having_tracking, :boolean, default: false
  end
end
