class AddColumnsToEbayCredential < ActiveRecord::Migration[5.1]
  def change
  	add_column :ebay_credentials, :shipped_status, :boolean, :default => false
    add_column :ebay_credentials, :unshipped_status, :boolean, :default => false
  end
end
