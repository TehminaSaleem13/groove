class CreateCarts < ActiveRecord::Migration[6.1]
  def change
    create_table :carts do |t|
      t.string :cart_id
      t.string :cart_name
      t.integer :number_of_totes

      t.timestamps
    end
  end
end
