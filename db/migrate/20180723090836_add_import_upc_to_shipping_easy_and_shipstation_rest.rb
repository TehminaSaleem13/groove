class AddImportUpcToShippingEasyAndShipstationRest < ActiveRecord::Migration[5.1]
  def change
    add_column :shipping_easy_credentials, :import_upc, :boolean, default: false
    add_column :shipstation_rest_credentials, :import_upc, :boolean, default: false
  end
end
