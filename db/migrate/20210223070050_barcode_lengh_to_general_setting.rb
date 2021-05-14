class BarcodeLenghToGeneralSetting < ActiveRecord::Migration[5.1]
  def change
    add_column :general_settings, :barcode_length, :integer, default: 8
    add_column :general_settings, :starting_value, :integer, default: 10000000
  end
end
