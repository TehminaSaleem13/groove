class AddProductReceivingInstructionsToProducts < ActiveRecord::Migration
  def change
    add_column :products, :product_receiving_instructions, :string
  end
end
