class AddAddedToReceivingInstructionsToProductImages < ActiveRecord::Migration
  def change
    add_column :product_images, :added_to_receiving_instructions, :boolean, :default=>false
  end
end
