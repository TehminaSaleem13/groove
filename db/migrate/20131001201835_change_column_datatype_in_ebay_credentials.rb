class ChangeColumnDatatypeInEbayCredentials < ActiveRecord::Migration
  def up
    remove_column :ebay_credentials, :productauth_token
    remove_column :ebay_credentials, :auth_token
    add_column :ebay_credentials, :productauth_token, :text
    add_column :ebay_credentials, :auth_token, :text
  end

  def down
    remove_column :ebay_credentials, :auth_token
    remove_column :ebay_credentials, :productauth_token
    add_column :ebay_credentials, :auth_token, :string, :default=>''
    add_column :ebay_credentials, :productauth_token, :string, :default=>''
  end
end
