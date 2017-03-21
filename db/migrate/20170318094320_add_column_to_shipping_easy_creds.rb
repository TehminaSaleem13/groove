class AddColumnToShippingEasyCreds < ActiveRecord::Migration
  def change
  	add_column :shipping_easy_credentials, :ready_to_ship, :boolean, :default => false 
  end
end
