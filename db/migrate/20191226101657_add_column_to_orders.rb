class AddColumnToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :last_modified, :datetime, default: nil
  end
end
