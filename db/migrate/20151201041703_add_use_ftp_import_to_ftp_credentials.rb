class AddUseFtpImportToFtpCredentials < ActiveRecord::Migration
  def change
    add_column :ftp_credentials, :use_ftp_import, :boolean, :default => false
  end
end
