class AddVeeqoAllocationIdToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :veeqo_allocation_id, :string
  end
end
