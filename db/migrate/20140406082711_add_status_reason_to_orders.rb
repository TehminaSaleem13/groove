class AddStatusReasonToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :status_reason, :string
  end
end
