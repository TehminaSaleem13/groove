class AddSendExternalLogsToScanPackSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :send_external_logs, :boolean, default: false
  end
end
