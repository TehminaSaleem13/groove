class AddContractedCarrierToShipstationRestCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :contracted_carriers, :text
    add_column :shipstation_rest_credentials, :presets, :text
  end
end
