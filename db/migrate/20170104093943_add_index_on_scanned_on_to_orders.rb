class AddIndexOnScannedOnToOrders < ActiveRecord::Migration[5.1]
  def change
  	unless index_exists? :orders, :scanned_on
  		add_index :orders, [:scanned_on]
  	end
  end
end
