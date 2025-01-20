class AddEnableServiceIssueStatusToScanPackSettings < ActiveRecord::Migration[6.1]
  def change
    add_column :scan_pack_settings, :enable_service_issue_status, :boolean, default: true, null: false
  end
end
