class AddPackingCamSettingOptionsToScanPackSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :scan_pack_settings, :packing_cam_enabled, :boolean, default: false
    add_column :scan_pack_settings, :email_customer_option, :boolean, default: false
    add_column :scan_pack_settings, :email_subject, :text
    add_column :scan_pack_settings, :email_insert_dropdown, :string, default: 'order_number'
    add_column :scan_pack_settings, :email_message, :text
    add_column :scan_pack_settings, :email_logo, :string
    add_column :scan_pack_settings, :customer_page_dropdown, :string, default: 'order_number'
    add_column :scan_pack_settings, :customer_page_message, :text
    add_column :scan_pack_settings, :customer_page_logo, :string
    add_column :scan_pack_settings, :scanning_log, :boolean, default: false
  end
end
