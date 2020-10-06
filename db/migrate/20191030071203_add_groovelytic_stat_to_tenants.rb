class AddGroovelyticStatToTenants < ActiveRecord::Migration[5.1]
  def change
      add_column :tenants, :groovelytic_stat, :boolean, :default => true
  end
end
