class AddColumnsToShopifyCredential < ActiveRecord::Migration[5.1]
  def change
  	add_column :shopify_credentials, :status, :string, :default => "open"
  	add_column :shopify_credentials, :shipped_status, :boolean, :default => 0
  	add_column :shopify_credentials, :unshipped_status, :boolean, :default => 0
  	add_column :shopify_credentials, :partial_status, :boolean, :default => 0
  end
end
