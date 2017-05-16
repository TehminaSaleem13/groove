class AddColumnToAmazonCredential < ActiveRecord::Migration
  def change
  	add_column :amazon_credentials, :shipped_status, :boolean, :default => false
    add_column :amazon_credentials, :unshipped_status, :boolean, :default => false
  end
end
