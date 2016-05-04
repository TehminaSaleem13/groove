class AddColumnMwsAuthTokenToAmazonCredentials < ActiveRecord::Migration
  def change
    add_column :amazon_credentials, :mws_auth_token, :string
  end
end
