class CreateEbayCredentials < ActiveRecord::Migration
  def change
    create_table :ebay_credentials do |t|
      t.string :dev_id, :null=>false
      t.string :app_id, :null=>false
      t.string :cert_id, :null=>false
      t.string :auth_token, :null=>false
      t.references :store
      t.timestamps
    end
  end
end
