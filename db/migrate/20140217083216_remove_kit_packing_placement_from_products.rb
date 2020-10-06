class RemoveKitPackingPlacementFromProducts < ActiveRecord::Migration[5.1]
  def up
    remove_column :products, :kit_packing_placement
  end

  def down
    add_column :products, :kit_packing_placement, :integer, :default=>50
  end
end
