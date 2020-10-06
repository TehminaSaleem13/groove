class AddProductFtpFieldsToFtpCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :ftp_credentials, :use_product_ftp_import, :boolean, default: false
    add_column :ftp_credentials, :product_ftp_connection_method, :string, default: 'ftp'
    add_column :ftp_credentials, :product_ftp_host, :string
    add_column :ftp_credentials, :product_ftp_username, :string, default: ''
    add_column :ftp_credentials, :product_ftp_password, :string, default: ''
    add_column :ftp_credentials, :product_ftp_connection_established, :boolean, default: false
  end
end
