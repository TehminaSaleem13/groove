class ChangeIsCfDefaultToTenants < ActiveRecord::Migration[5.1]
  def change
    change_column_default :tenants, :is_cf, from: false, to: true
  end
end
