class AddQtyToProductLots < ActiveRecord::Migration
  def up
    add_column :product_lots, :qty, :integer, :default => 0
  end

  def down
  	remove_column :product_lots, :qty
  end
end
