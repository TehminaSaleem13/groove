class AddShowSkuInBarcodeslipColumnToGeneralSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :general_settings, :show_sku_in_barcodeslip, :boolean, default: true
  end
end
