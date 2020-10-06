class AddFieldToSettings < ActiveRecord::Migration[5.1]
  def change
  	add_column :general_settings, :hex_barcode, :boolean, default: false
  end
end
