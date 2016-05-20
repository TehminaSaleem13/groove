class AddColumnOnDemandImportToStores < ActiveRecord::Migration
  def change
    add_column :stores, :on_demand_import, :boolean, :default => false
  end
end
