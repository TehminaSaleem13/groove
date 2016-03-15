class CreateTeapplixCredentials < ActiveRecord::Migration
  def change
    create_table :teapplix_credentials do |t|
      t.integer :store_id
      t.string :account_name
      t.string :username
      t.string :password

      t.timestamps
    end
  end
end
