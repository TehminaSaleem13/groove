class AddConnectionEstablishedToFtpCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :ftp_credentials, :connection_established, :boolean, :default => false
  end
end
