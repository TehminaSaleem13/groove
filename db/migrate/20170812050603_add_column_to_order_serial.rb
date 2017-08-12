class AddColumnToOrderSerial < ActiveRecord::Migration
  def change
  	add_column :order_serials, :second_serial, :string
  end
end
