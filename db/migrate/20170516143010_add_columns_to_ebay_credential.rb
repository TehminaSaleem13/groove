class AddColumnsToEbayCredential < ActiveRecord::Migration
  def change
  	add_column :ebay_credentials, :shipped_status, :boolean, :default => false
    add_column :ebay_credentials, :unshipped_status, :boolean, :default => false
  end
end
