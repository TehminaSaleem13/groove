class AddSerialToProduct < ActiveRecord::Migration
  def change
  	add_column :products, :second_record_serial, :boolean, :default => false
  end
end
