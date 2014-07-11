	class SeedTenant
		def seed
			if User.where(:username=>'admin').length == 0
				User.create([{:username=>'admin', :name=>'Admin', :email => "abc@gmail.com", :password => "12345678",
					:password_confirmation => "12345678", :confirmation_code=>'1234567890', :active=> true}],:without_protection=>true)
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

			if GeneralSetting.all.length == 1
			  general_setting = GeneralSetting.all.first
			  general_setting.product_weight_format = 'English'
			  general_setting.packing_slip_size = '4 x 6'
			  general_setting.packing_slip_orientation = 'portrait'
			  general_setting.time_to_import_orders = '2001-01-01 00:00:00'
			  general_setting.time_to_send_email = '2001-01-01 00:00:00'
			  general_setting.scheduled_order_import = true
			  general_setting.import_orders_on_mon = false
			  general_setting.import_orders_on_tue = false
			  general_setting.import_orders_on_wed = false
			  general_setting.import_orders_on_thurs = false
			  general_setting.import_orders_on_fri = false
			  general_setting.import_orders_on_sat = false
			  general_setting.import_orders_on_sun = false
			  general_setting.save
			end

			if Role.all.length == 0
			  roles = Role.create([
			    {
			      :name=>'Super Admin',
			      :display => true,
			      :custom => false,

			      :add_edit_order_items => true,
			      :import_orders => true,
			      :change_order_status => true,
			      :create_edit_notes => true,
			      :view_packing_ex => true,
			      :create_packing_ex => true,
			      :edit_packing_ex => true,

			      :delete_products => true,
			      :import_products => true,
			      :add_edit_products => true,

			      :add_edit_users => true,
			      :make_super_admin => true,

			      :access_scanpack => true,
			      :access_orders => true,
			      :access_products => true,
			      :access_settings => true,


			      :edit_general_prefs => true,
			      :edit_scanning_prefs => true,
			      :add_edit_stores => true,
			      :create_backups => true,
			      :restore_backups => true
			    },
			    {
			       :name=>'Admin',
			       :display => true,
			       :custom => false,

			       :add_edit_order_items => true,
			       :import_orders => true,
			       :change_order_status => true,
			       :create_edit_notes => true,
			       :view_packing_ex => true,
			       :create_packing_ex => true,
			       :edit_packing_ex => true,

			       :delete_products => false,
			       :import_products => true,
			       :add_edit_products => true,

			       :add_edit_users => true,
			       :make_super_admin => false,

			       :access_scanpack => true,
			       :access_orders => true,
			       :access_products => true,
			       :access_settings => true,


			       :edit_general_prefs => true,
			       :edit_scanning_prefs => true,
			       :add_edit_stores => false,
			       :create_backups => true,
			       :restore_backups => false
			    },
			    {
			        :name=>'Manager',
			        :display => true,
			        :custom => false,

			        :add_edit_order_items => true,
			        :import_orders => true,
			        :change_order_status => true,
			        :create_edit_notes => true,
			        :view_packing_ex => true,
			        :create_packing_ex => true,
			        :edit_packing_ex => false,

			        :delete_products => false,
			        :import_products => false,
			        :add_edit_products => true,

			        :add_edit_users => false,
			        :make_super_admin => false,

			        :access_scanpack => true,
			        :access_orders => true,
			        :access_products => true,
			        :access_settings => false,


			        :edit_general_prefs => false,
			        :edit_scanning_prefs => false,
			        :add_edit_stores => false,
			        :create_backups => true,
			        :restore_backups => false
			    },
			    {
			        :name=>'Scan & Pack User',
			        :display => true,
			        :custom => false,

			        :add_edit_order_items => false,
			        :import_orders => true,
			        :change_order_status => false,
			        :create_edit_notes => false,
			        :view_packing_ex => false,
			        :create_packing_ex => false,
			        :edit_packing_ex => false,

			        :delete_products => false,
			        :import_products => false,
			        :add_edit_products => false,

			        :add_edit_users => false,
			        :make_super_admin => false,

			        :access_scanpack => true,
			        :access_orders => false,
			        :access_products => false,
			        :access_settings => false,


			        :edit_general_prefs => false,
			        :edit_scanning_prefs => false,
			        :add_edit_stores => false,
			        :create_backups => false,
			        :restore_backups => false
			    }], :without_protection => true
			  )
			end

			role_super_admin = Role.find_by_name('Super Admin')
			unless role_super_admin.nil?
			  Role.columns.each do |col|
			    if col.type == :boolean && col.name != "custom"
			      role_super_admin[col.name] = true
			    end

			  end
			  role_super_admin.save
			end



			User.all.each do |user|
			  if user.role.nil?
			    if user.username == 'admin'
			      user.role = role_super_admin
			    else
			      user.role = Role.find_by_name('Scan & Pack User')
			    end
			    user.save
			  end
			end
		end
	end