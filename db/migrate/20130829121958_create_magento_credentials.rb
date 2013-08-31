class CreateMagentoCredentials < ActiveRecord::Migration
  def change
    create_table :magento_credentials do |t|
      t.string :host, :null=>false
      t.string :username, :null=>false
      t.string :password, :null=>false
      t.references :store, :null=>false
      t.timestamps
    end
  end
end
