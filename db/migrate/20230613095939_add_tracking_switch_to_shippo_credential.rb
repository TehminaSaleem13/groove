class AddTrackingSwitchToShippoCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shippo_credentials, :import_shipped_having_tracking, :boolean, default: false
  end
end
