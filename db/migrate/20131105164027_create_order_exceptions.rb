class CreateOrderExceptions < ActiveRecord::Migration
  def change
    create_table :order_exceptions do |t|
      t.string :reason
      t.string :description
      t.references :user

      t.timestamps
    end
    add_index :order_exceptions, :user_id
  end
end
