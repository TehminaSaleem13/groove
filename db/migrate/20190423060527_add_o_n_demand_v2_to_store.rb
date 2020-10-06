class AddONDemandV2ToStore < ActiveRecord::Migration[5.1]
  def change
    add_column :stores, :on_demand_import_v2, :boolean, :default => false
    add_column :stores, :regular_import_v2, :boolean, :default => false
  end
end
