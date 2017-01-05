class AddIndexOnScannedOnToOrders < ActiveRecord::Migration
  def change
  	add_index :orders, [:scanned_on]
  end
end
