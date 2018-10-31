class AddAllowRtsToTenant < ActiveRecord::Migration
  def change
    add_column :tenants, :allow_rts, :boolean, :default => false
  end
end
