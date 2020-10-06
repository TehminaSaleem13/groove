class ChangePendingOrderTypeInTotes < ActiveRecord::Migration[5.1]
  def up
    change_column :totes, :pending_order_id, :boolean, :using => 'case when pending_order_id then true else false end', default: false
    rename_column :totes, :pending_order_id, :pending_order
  end

  def down
    rename_column :totes, :pending_order, :pending_order_id
    change_column :totes, :pending_order_id, :integer
  end
end
