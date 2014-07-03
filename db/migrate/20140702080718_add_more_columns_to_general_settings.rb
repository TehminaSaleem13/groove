class AddMoreColumnsToGeneralSettings < ActiveRecord::Migration
  def change
  	add_column :general_settings, :import_orders_on_mon, :boolean, :default => false
    add_column :general_settings, :import_orders_on_tue, :boolean, :default => false
    add_column :general_settings, :import_orders_on_wed, :boolean, :default => false
    add_column :general_settings, :import_orders_on_thurs, :boolean, :default => false
    add_column :general_settings, :import_orders_on_fri, :boolean, :default => false
    add_column :general_settings, :import_orders_on_sat, :boolean, :default => false
    add_column :general_settings, :import_orders_on_sun, :boolean, :default => false
    add_column :general_settings, :time_to_import_orders, :time, :default => '00:00:00'
    add_column :general_settings, :scheduled_order_import, :boolean, :default => true
  end
end
