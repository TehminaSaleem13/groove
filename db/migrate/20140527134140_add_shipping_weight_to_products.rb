class AddShippingWeightToProducts < ActiveRecord::Migration
  def up
  	add_column :products, :shipping_weight, :decimal, :precision => 8, :scale => 2, :default => '0'
  end
  def down
  	remove_column :products, :shipping_weight
  end
end
