class CreateAmazonCredentials < ActiveRecord::Migration
  def change
    create_table :amazon_credentials do |t|
      t.string :access_key_id, :null=>false
      t.string :secret_access_key, :null=>false
      t.string :app_name, :null=>false
      t.string :app_version, :null=>false
      t.string :merchant_id,:null=>false
      t.string :marketplace_id, :null=>false
      t.references :store
      t.timestamps
    end
  end
end
