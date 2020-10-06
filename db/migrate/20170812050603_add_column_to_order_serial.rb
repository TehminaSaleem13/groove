class AddColumnToOrderSerial < ActiveRecord::Migration[5.1]
  def change
  	unless column_exists? :order_serials, :second_serial
  		add_column :order_serials, :second_serial, :string
  	end
  end
end
