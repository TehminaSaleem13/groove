class CreateShipstationRestCredentialTable < ActiveRecord::Migration
  def up
    create_table :shipstation_rest_credentials do |t|
      t.string :api_key, null: false
      t.string :api_secret, null: false
      t.date :last_imported_at, default: nil
      t.integer :store_id, null: false
      t.timestamps
    end
  end

  def down
    drop_table :shipstation_rest_credentials
  end
end
