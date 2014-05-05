class AddStatusReasonToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :status_reason, :string
  end
end
