class AddWebhookSecretToShipstationRestCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :webhook_secret, :string, default: ''
  end
end
