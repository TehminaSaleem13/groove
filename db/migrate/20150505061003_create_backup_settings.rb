class CreateBackupSettings < ActiveRecord::Migration
  def change
    create_table :backup_settings do |t|
    	t.boolean :auto_email_export, :default=>true
    	t.datetime    :time_to_send_export_email
    	t.boolean :send_export_email_on_mon, :default=>false
    	t.boolean :send_export_email_on_tue, :default=>false
    	t.boolean :send_export_email_on_wed, :default=>false
    	t.boolean :send_export_email_on_thu, :default=>false
    	t.boolean :send_export_email_on_fri, :default=>false
    	t.boolean :send_export_email_on_sat, :default=>false
    	t.boolean :send_export_email_on_sun, :default=>false
    	t.datetime    :last_exported
    	t.string  :export_orders_option, :default=>'on_same_day'
    	t.string  :order_export_type,    :default=>'include_all'
    	t.string  :order_export_email

      t.timestamps
    end
  end
end
