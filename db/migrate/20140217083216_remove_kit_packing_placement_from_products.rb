class RemoveKitPackingPlacementFromProducts < ActiveRecord::Migration
  def up
    remove_column :products, :kit_packing_placement
  end

  def down
    add_column :products, :kit_packing_placement, :integer, :default=>50
  end
end
