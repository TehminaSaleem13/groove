class ModifyProductReceivingInstructionsTypeInProducts < ActiveRecord::Migration[5.1]
  def up
  	remove_column :products, :product_receiving_instructions
  	add_column :products, :product_receiving_instructions, :text
  end

  def down
  	remove_column :products, :product_receiving_instructions
  	add_column :products, :product_receiving_instructions, :string
  end
end
