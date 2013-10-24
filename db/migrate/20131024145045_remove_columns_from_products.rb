class RemoveColumnsFromProducts < ActiveRecord::Migration
  def up
  	remove_column :products, :kit_skus
  end

  def down
  	add_column :products, :kit_parsing, :string
  end
end
