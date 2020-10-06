class AddColumnToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :last_modified, :datetime, default: nil
  end
end
