class CreateOrderShippings < ActiveRecord::Migration
  def change
    create_table :order_shippings do |t|
      t.string :firstname
      t.string :lastname
      t.string :email
      t.string :streetaddress1
      t.string :streetaddress2
      t.string :city
      t.string :region
      t.string :postcode
      t.string :country
      t.string :description
      t.references :order
      t.timestamps
    end
  end
end
