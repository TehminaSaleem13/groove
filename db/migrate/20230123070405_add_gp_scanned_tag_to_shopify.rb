class AddGpScannedTagToShopify < ActiveRecord::Migration[5.1]
  def change
    add_column :shopify_credentials, :add_gp_scanned_tag, :boolean, default: false
  end
end
