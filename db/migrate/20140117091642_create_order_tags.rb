class CreateOrderTags < ActiveRecord::Migration[5.1]
  def change
    create_table :order_tags do |t|
      t.string :name, :null=>false
      t.string :color, :null=>false
      t.string :mark_place, :default => 0

      t.timestamps
    end
  end
end
