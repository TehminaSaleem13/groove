class AddRequestSerialToProduct < ActiveRecord::Migration
  def change
    add_column :products, :record_serial, :boolean, :default => false
  end
end
