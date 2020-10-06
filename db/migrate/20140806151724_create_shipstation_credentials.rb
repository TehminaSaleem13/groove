class CreateShipstationCredentials < ActiveRecord::Migration[5.1]
  def up
    create_table :shipstation_credentials do |t|
    	t.string :username, :null=>false
      t.string :password, :null=>false

      t.timestamps
    end
  end
  def down
  	drop_table :shipstation_credentials
  end
end
