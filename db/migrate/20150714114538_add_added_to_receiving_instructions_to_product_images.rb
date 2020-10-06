class AddAddedToReceivingInstructionsToProductImages < ActiveRecord::Migration[5.1]
  def change
    add_column :product_images, :added_to_receiving_instructions, :boolean, :default=>false
  end
end
