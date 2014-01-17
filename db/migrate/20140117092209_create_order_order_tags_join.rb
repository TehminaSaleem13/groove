class CreateOrderOrderTagsJoin < ActiveRecord::Migration
  def up
          create_table :order_tags_orders, :id => false do |t|
                  t.integer "order_id"
                  t.integer "order_tag_id"
          end
          add_index :order_tags_orders, ["order_id","order_tag_id"]
  end

  def down
          drop_table :order_tags_orders
  end
end
