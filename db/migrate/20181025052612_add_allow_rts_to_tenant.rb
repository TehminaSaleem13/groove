class AddAllowRtsToTenant < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :allow_rts, :boolean, :default => false
  end
end
