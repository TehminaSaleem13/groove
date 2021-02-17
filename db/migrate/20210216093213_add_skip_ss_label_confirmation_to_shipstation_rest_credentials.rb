class AddSkipSsLabelConfirmationToShipstationRestCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :skip_ss_label_confirmation, :boolean, default:  false
  end
end
