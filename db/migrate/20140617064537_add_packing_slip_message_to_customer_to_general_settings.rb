class AddPackingSlipMessageToCustomerToGeneralSettings < ActiveRecord::Migration
  def up
    add_column :general_settings, :packing_slip_message_to_customer, :text
  end
  def down
  	remove_column :general_settings, :packing_slip_message_to_customer
  end
end
