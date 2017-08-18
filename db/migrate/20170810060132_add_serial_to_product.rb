class AddSerialToProduct < ActiveRecord::Migration
  def change
  	unless column_exists? :products, :second_record_serial
  		add_column :products, :second_record_serial, :boolean, :default => false
  	end
  end
end
