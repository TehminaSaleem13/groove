class AddKitPackingPlacementToProducts < ActiveRecord::Migration
  def change
    add_column :products, :kit_packing_placement, :integer, :default => 50
  end
end
