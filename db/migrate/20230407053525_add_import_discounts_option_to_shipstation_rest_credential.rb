class AddImportDiscountsOptionToShipstationRestCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :import_discounts_option, :boolean, default: false
  end
end
