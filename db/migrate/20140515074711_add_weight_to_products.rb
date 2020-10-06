class AddWeightToProducts < ActiveRecord::Migration[5.1]
  def up
  	add_column :products, :weight, :decimal, :precision => 8, :scale => 2, :null => false, :default => '0'
  end
  def down
  	remove_column :products, :weight
  end
end
