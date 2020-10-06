class AddImportStoreOrderNumberToShipworksCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :shipworks_credentials, :import_store_order_number, :boolean, default: false
  end
end
