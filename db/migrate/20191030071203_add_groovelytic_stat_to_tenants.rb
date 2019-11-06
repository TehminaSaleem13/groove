class AddGroovelyticStatToTenants < ActiveRecord::Migration
  def change
      add_column :tenants, :groovelytic_stat, :boolean, :default => true
  end
end
