class ChangeDefaultPackingPlacementForProducts < ActiveRecord::Migration[5.1]
  def up
  	change_column :products, :packing_placement, :integer, :default=>50
  end

  def down
  	change_column :products, :packing_placement, :integer, {:default=>nil}
  end
end
