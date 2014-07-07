class ChangeDateFormatInGeneralSettings < ActiveRecord::Migration
  def up
  	change_column :general_settings, :time_to_send_email, :datetime
  	change_column :general_settings, :time_to_import_orders, :datetime
  end

  def down
  	change_column :general_settings, :time_to_send_email, :date
  	change_column :general_settings, :time_to_import_orders, :date
  end
end
