class AddConnectionMethodToFtpCredentials < ActiveRecord::Migration
  def change
    add_column :ftp_credentials, :connection_method, :string, :default => 'ftp'
  end
end
