class AddIsCfToTenant < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :is_cf, :boolean, default: false
  end
end
