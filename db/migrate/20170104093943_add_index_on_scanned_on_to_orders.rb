class AddIndexOnScannedOnToOrders < ActiveRecord::Migration
  def change
  	unless index_exists? :orders, :scanned_on
  		add_index :orders, [:scanned_on]
  	end
  end
end
