class UpdateGeneralSettingDisableHoldOrdersDueToInventoryByDefault < ActiveRecord::Migration[5.1]
  def up
    change_column_default :general_settings, :hold_orders_due_to_inventory, false
  end

  def down
    change_column_default :general_settings, :hold_orders_due_to_inventory, true
  end
end
