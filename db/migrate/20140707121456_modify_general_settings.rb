class ModifyGeneralSettings < ActiveRecord::Migration
  def up
  	general_setting = GeneralSetting.all.first
  	if !general_setting.nil?
			general_setting.time_to_send_email = '2000-01-01'			
			general_setting.time_to_import_orders = '2000-01-01'
			general_setting.save
		end
  end
  def down
  end
end
