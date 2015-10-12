class AddConnectionEstablishedToFtpCredentials < ActiveRecord::Migration
  def change
    add_column :ftp_credentials, :connection_established, :boolean, :default => false
  end
end
