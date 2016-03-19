class CreateTeapplixCredentials < ActiveRecord::Migration
  def change
    create_table :teapplix_credentials do |t|
      t.integer :store_id
      t.string :account_name
      t.string :username
      t.string :password
      t.boolean :import_shipped, :default => false
      t.boolean :import_open_orders, :default => false
      t.datetime :last_imported_at

      t.timestamps
    end
  end
end
