class CreateBigCommerceCredentials < ActiveRecord::Migration
  def change
    create_table :big_commerce_credentials do |t|
      t.integer :store_id
      t.string :shop_name
      t.string :store_hash
      t.string :access_token

      t.timestamps
    end
  end
end
