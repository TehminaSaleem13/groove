class RemoveColumnsFromProducts < ActiveRecord::Migration[5.1]
  def up
  	remove_column :products, :kit_skus
  end

  def down
  	add_column :products, :kit_parsing, :string
  end
end
