class AddFieldToSettings < ActiveRecord::Migration
  def change
  	add_column :general_settings, :hex_barcode, :boolean, default: false
  end
end
