class DeleteColumnsFromEbayCredentials < ActiveRecord::Migration
  def up
      remove_column :ebay_credentials, :app_id
      remove_column :ebay_credentials, :cert_id
      remove_column :ebay_credentials, :productdev_id
      remove_column :ebay_credentials, :productapp_id
      remove_column :ebay_credentials, :productcert_id
  end

  def down
  	add_column :ebay_credentials, :productapp_id, :string, :default=>'', :null=>false
  	add_column :ebay_credentials, :productcert_id, :string, :default=>'', :null=>false
	add_column :ebay_credentials, :productdev_id, :string, :default=>'', :null=>false
  	add_column :ebay_credentials, :app_id, :string, :default=>'', :null=>false
  	add_column :ebay_credentials, :cert_id, :string, :default=>'', :null=>false
  end
end
