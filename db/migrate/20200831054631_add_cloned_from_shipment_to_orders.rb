class AddClonedFromShipmentToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :cloned_from_shipment_id, :string, default: ''
  end
end
