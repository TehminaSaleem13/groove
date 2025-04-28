class AddScanToScoreToTenants < ActiveRecord::Migration[6.1]
  def change
    add_column :tenants, :scan_to_score, :boolean, default: false
  end
end
