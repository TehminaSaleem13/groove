class AddRequestSerialToProduct < ActiveRecord::Migration[5.1]
  def change
    add_column :products, :record_serial, :boolean, :default => false
  end
end
