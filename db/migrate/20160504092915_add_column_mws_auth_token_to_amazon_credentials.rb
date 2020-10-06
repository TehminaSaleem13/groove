class AddColumnMwsAuthTokenToAmazonCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :amazon_credentials, :mws_auth_token, :string
  end
end
