class CreateGeneralSettings < ActiveRecord::Migration
  def change
    create_table :general_settings do |t|
      t.boolean :inventory_tracking, :default=>1
      t.boolean :low_inventory_alert_email, :default=>1
      t.string :low_inventory_email_address, :default=>''
      t.boolean :hold_orders_due_to_inventory, :default=>1
      t.string :conf_req_on_notes_to_packer, :default=>'optional'
      t.string :send_email_for_packer_notes, :default=>'always'
      t.string :email_address_for_packer_notes, :default=>''

      t.timestamps
    end
  end
end
