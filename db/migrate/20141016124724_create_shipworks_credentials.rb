class CreateShipworksCredentials < ActiveRecord::Migration
  def change
    create_table :shipworks_credentials do |t|
      t.string :auth_token, :null=> false
      t.integer :store_id, :null => false

      t.timestamps
    end
  end
end
