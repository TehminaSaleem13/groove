class ChangeDefaultForIsKitInProducts < ActiveRecord::Migration
  def up
  	remove_column :products, :is_kit
  	add_column :products, :is_kit, :integer, :default=>0
  end

  def down
  	remove_column :products, :is_kit
  	add_column :products, :is_kit, :integer
  end
end
