class GeneralSetting < ActiveRecord::Base
  attr_accessible :conf_req_on_notes_to_packer, :email_address_for_packer_notes, :hold_orders_due_to_inventory,
   :inventory_tracking, :low_inventory_alert_email, :low_inventory_email_address, :send_email_for_packer_notes
end
