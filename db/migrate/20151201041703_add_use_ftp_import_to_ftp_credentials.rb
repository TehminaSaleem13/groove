class AddUseFtpImportToFtpCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :ftp_credentials, :use_ftp_import, :boolean, :default => false
  end
end
