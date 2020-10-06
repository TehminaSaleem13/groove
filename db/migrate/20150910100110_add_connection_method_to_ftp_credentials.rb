class AddConnectionMethodToFtpCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :ftp_credentials, :connection_method, :string, :default => 'ftp'
  end
end
