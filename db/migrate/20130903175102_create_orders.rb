class CreateOrders < ActiveRecord::Migration
  def change
    create_table :orders do |t|
      t.integer :increment_id
      t.datetime :order_placed_time
      t.string :sku
      t.text :customer_comments
      t.integer :store_id
      t.integer :qty
      t.decimal :price
      t.string :firstname
      t.string :lastname
      t.string :email
      t.text :address_1
      t.text :address_2
      t.string :city
      t.string :state
      t.string :postcode
      t.string :country
      t.string :method

      t.timestamps
    end
  end
end
