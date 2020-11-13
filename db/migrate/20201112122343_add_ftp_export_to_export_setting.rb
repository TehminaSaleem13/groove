class AddFtpExportToExportSetting < ActiveRecord::Migration[5.1]
  def change
    add_column :export_settings, :auto_ftp_export, :boolean, default: false
  end
end
