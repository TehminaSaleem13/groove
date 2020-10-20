class ChangeDailyPackedEmailExportDefault < ActiveRecord::Migration[5.1]
  def up
    change_column :export_settings, :daily_packed_email_export, :boolean, default: false
  end

  def down
    change_column :export_settings, :daily_packed_email_export, :boolean, default: true
  end
end
