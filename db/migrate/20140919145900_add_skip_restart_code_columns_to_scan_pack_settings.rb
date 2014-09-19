class AddSkipRestartCodeColumnsToScanPackSettings < ActiveRecord::Migration
  def change
    add_column :scan_pack_settings, :skip_code_enabled, :boolean, :default => true
    add_column :scan_pack_settings, :skip_code, :string, :default => 'SKIP'
    add_column :scan_pack_settings, :note_from_packer_code_enabled, :boolean, :default => true
    add_column :scan_pack_settings, :note_from_packer_code, :string, :default => 'NOTE'
    add_column :scan_pack_settings, :service_issue_code_enabled, :boolean, :default => true
    add_column :scan_pack_settings, :service_issue_code, :string, :default => 'ISSUE'
    add_column :scan_pack_settings, :restart_code_enabled, :boolean, :default => true
    add_column :scan_pack_settings, :restart_code, :string, :default => 'RESTART'
  end
end
