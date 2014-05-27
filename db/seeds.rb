# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

if User.where(:username=>'admin').length == 0
	User.create(:username=>'admin', :email => "abc@gmail.com", :password => "12345678",
		:password_confirmation => "12345678", :confirmation_code=>'1234567890')
	#user = User.create(:username=>'admin', :password=>'12345678')
end

if OrderTag.where(:name=>'Contains New').length == 0
	contains_new_tag = OrderTag.create(:name=>'Contains New', :color=>'#FF0000', :predefined => true)
end

if OrderTag.where(:name=>'Contains Inactive').length == 0
	contains_inactive_tag = OrderTag.create(:name=>'Contains Inactive', :color=>'#00FF00', :predefined => true)
end

if OrderTag.where(:name=>'Manual Hold').length == 0
	manual_hold_tag = OrderTag.create(:name=>'Manual Hold', :color=>'#0000FF', :predefined => true)
end

if InventoryWarehouse.where(:name=>'Default Warehouse').length == 0
  default_location = InventoryWarehouse.create(:name=>'Default Warehouse', :location=> 'Default Warehouse', :status => 'active', :is_default => 1)
end

if Store.where(:store_type=>'system').length == 0
  system_store = Store.create(:name=>'GroovePacker', :store_type=>'system',:status=>true)
end

if GeneralSetting.all.length == 0
  general_setting = GeneralSetting.create(:inventory_tracking=>1, 
  		:low_inventory_alert_email => 1, 
  		:low_inventory_email_address => '',
  		:hold_orders_due_to_inventory=> 1,
  		:conf_req_on_notes_to_packer => 'optional',
  		:send_email_for_packer_notes => 'always',
  		:email_address_for_packer_notes => '')
end