class AddClonedFromShipmentToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :cloned_from_shipment_id, :string, default: ''
  end
end
