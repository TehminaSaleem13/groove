class AddTruncateOrderNumberToGeneralSetting < ActiveRecord::Migration[5.1]
  def change
    add_column :general_settings, :truncate_order_number_in_packing_slip, :boolean, default: false
  end
end
