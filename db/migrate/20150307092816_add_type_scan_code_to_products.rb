class AddTypeScanCodeToProducts < ActiveRecord::Migration[5.1]
  def change
    add_column :products, :type_scan_enabled, :string, :default => 'on'
    add_column :products, :click_scan_enabled, :string, :default => 'on'
  end
end
