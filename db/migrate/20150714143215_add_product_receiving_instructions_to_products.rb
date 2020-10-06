class AddProductReceivingInstructionsToProducts < ActiveRecord::Migration[5.1]
  def change
    add_column :products, :product_receiving_instructions, :string
  end
end
