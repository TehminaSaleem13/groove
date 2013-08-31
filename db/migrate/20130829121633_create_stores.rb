class CreateStores < ActiveRecord::Migration
  def change
    create_table :stores do |t|
      t.string :name, :null=>false, :unique=>true
      t.boolean :status, :null=>false, :default=>0
      t.string :store_type, :null=>false
      t.date :order_date

      t.timestamps
    end
  end
end
