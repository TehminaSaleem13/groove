class CreateOrders < ActiveRecord::Migration
  def change
    create_table :orders do |t|
      t.string :status
      t.string :storename
      t.string :customercomments
      t.references :store

      t.timestamps
    end
    add_index :orders, :store_id
  end
end
