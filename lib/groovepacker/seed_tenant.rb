module Groovepacker
  class SeedTenant
    include InventoryWarehouseHelper

    def seed(create = false, username='admin', email='abc@gmail.com', password='12345678')

      case Rails.env
        when "development"
          if AccessRestriction.all.length == 0
            AccessRestriction.create(
              num_users: '12',
              num_shipments: '50000',
              num_import_sources: '8',
              total_scanned_shipments: '0'
            )
          end
      end

      if OrderTag.where(:name => 'Contains New').length == 0
        contains_new_tag = OrderTag.create(:name => 'Contains New', :color => '#FF0000', :predefined => true)
      end

      if OrderTag.where(:name => 'Contains Inactive').length == 0
        contains_inactive_tag = OrderTag.create(:name => 'Contains Inactive', :color => '#00FF00', :predefined => true)
      end

      if OrderTag.where(:name => 'Manual Hold').length == 0
        manual_hold_tag = OrderTag.create(:name => 'Manual Hold', :color => '#0000FF', :predefined => true)
      end

      if InventoryWarehouse.where(:is_default => true).length == 0
        default_location = InventoryWarehouse.create(:name => 'Default Warehouse', :location => 'Default Warehouse', :status => 'active', :is_default => true)
      end

      #Added double collon before model name
      if ::Store.where(:store_type => 'system').length == 0
        system_store = ::Store.create(:name => 'GroovePacker', :store_type => 'system',
                                    :status => true, inventory_warehouse: InventoryWarehouse.first)
      end

      if GeneralSetting.all.length == 0
        general_setting = GeneralSetting.new
        general_setting.save
      end

      if PrintingSetting.all.length == 0
        printing_setting = PrintingSetting.new
        printing_setting.save
      end

      if ExportSetting.all.length == 0
        ExportSetting.create(:auto_email_export => 1,
                             :export_orders_option => 'on_same_day',
                             :order_export_type => 'do_not_include',
                             :send_export_email_on_mon => true,
                             :send_export_email_on_tue => true,
                             :send_export_email_on_wed => true,
                             :send_export_email_on_thu => true,
                             :send_export_email_on_fri => true)
      end

      if ScanPackSetting.all.length == 0
        ScanPackSetting.create(enable_click_sku: true, ask_tracking_number: false, intangible_setting_enabled: true, intangible_setting_gen_barcode_from_sku: true, intangible_string: "Coupon:", replace_gp_code: true, email_subject: 'YourCompany Order - [[ORDER-NUMBER]] - Packing Details', email_message: "<h4 style=\"color: rgb(85, 85, 85);background-color: rgb(255, 255, 255);\"><span>This email was sent on behalf of </span><b><b><b><i>http://YourCompany.com </i></b></b></b><span>to let you know your order number [[ORDER-NUMBER]] has been scanned by the fulfillment team. You can review an image of your order items and a scanning log here: [[CUSTOMER-PAGE-URL]]</span><br/></h4>", customer_page_message: '<h4>To ensure the accuracy of your order <i>YourCompany</i> scans every item as your package is packed. The image below was taken immediately after the items were scanned. The scanning log shows each scan.</h4><h4>If you see any issues, or if you need assistance, please contact support regarding your order here: <b><i>http://YourCompany.com/Support</i></b><br/></h4>')
      end

      [
        {
          :name => 'Super Super Admin',
          :display => false,
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
          :name => 'Super Admin',
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
          :name => 'Admin',
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
          :add_edit_stores => true,
          :create_backups => true,
          :restore_backups => false
        },
        {
          :name => 'Manager',
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
          :name => 'Scan & Pack User',
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
        }
      ].each do |role|
        cur_role = Role.find_or_create_by(name: role[:name])
        role.each do |key, value|
          cur_role[key] = value
        end
        cur_role.save
      end

      role_super_super_admin = Role.find_by_name('Super Super Admin')
      unless role_super_super_admin.nil?
        Role.columns.each do |col|
          if col.type == :boolean && col.name != 'custom' && col.name != 'display'
            role_super_super_admin[col.name] = true
          end

        end
        role_super_super_admin.save
      end

      role_super_admin = Role.find_by_name('Super Admin')
      unless role_super_admin.nil?
        Role.columns.each do |col|
          if col.type == :boolean && col.name != 'custom'
            role_super_admin[col.name] = true
          end

        end
        role_super_admin.save
      end

      if User.all.length == 0 || (User.where(:username => username).length == 0 && create)
        created_user = User.create({:username => username, :name => username, :email => email, :password => password,
                                     :password_confirmation => password, :role_id => role_super_admin.id, :confirmation_code => '12345678901', :active => true})
      end

      if User.where(:username => 'gpadmin').length == 0
        created_super_user = User.create({:username => 'gpadmin', :name => 'gpadmin', :password => '098poi)(*POI', :email => 'groovepacker@gmail.com',
                                           :password_confirmation => '098poi)(*POI', :role_id => role_super_super_admin.id, :confirmation_code => '12345678900', :active => true, :view_dashboard => "admin_dashboard_with_packer_stats"})
      end

      User.all.each do |user|
        if user.role.nil?
          user.role = Role.find_by_name('Scan & Pack User')
          user.save
        end
        if user.inventory_warehouse_id.nil?
          user.inventory_warehouse_id = InventoryWarehouse.where(:is_default => true).first.id
          user.save
        end
        InventoryWarehouse.all.each do |inv_wh|
          fix_user_inventory_permissions(user, inv_wh)
        end
      end
      ProductInventoryReport.create(name: "All_Products_Report", is_locked: true)
      ProductInventoryReport.create(name: "Active_Products_Report", is_locked: true)
    end
  end
end
