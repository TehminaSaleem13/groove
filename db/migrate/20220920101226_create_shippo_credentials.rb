class CreateShippoCredentials < ActiveRecord::Migration[5.1]
  def change
    create_table :shippo_credentials do |t|
      t.integer :store_id
      t.string :api_key
      t.string :api_version

      t.timestamps
    end
  end
end
