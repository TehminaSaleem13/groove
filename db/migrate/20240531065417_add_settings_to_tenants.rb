class AddSettingsToTenants < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :settings, :text

    Tenant.find_each do |tenant|
      tenant.update(mark_discrepancies_scanned: true)
    end
  end
end
