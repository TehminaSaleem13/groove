class AddFieldsToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :scanned_on, :date
    add_column :orders, :tracking_num, :string
    add_column :orders, :company, :string
  end
end
