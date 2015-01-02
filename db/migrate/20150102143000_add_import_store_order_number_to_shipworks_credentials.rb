class AddImportStoreOrderNumberToShipworksCredentials < ActiveRecord::Migration
  def change
    add_column :shipworks_credentials, :import_store_order_number, :boolean, default: false
  end
end
