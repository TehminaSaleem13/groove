class AddColumnOnDemandImportToStores < ActiveRecord::Migration[5.1]
  def change
    add_column :stores, :on_demand_import, :boolean, :default => false
  end
end
