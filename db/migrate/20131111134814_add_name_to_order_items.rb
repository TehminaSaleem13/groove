class AddNameToOrderItems < ActiveRecord::Migration[5.1]
  def change
    add_column :order_items, :name, :string, :null=>false, :default=>''
  end
end
