
namespace :user_role do
    desc 'Add User Roles'
    task add_user_roles: :environment do
      tenants = Tenant.pluck(:name)
      unless tenants.empty?
        tenants.each do |tenant|
          Apartment::Tenant.switch! tenant
          unless Role.find_by(name: "Administrative")
            Role.create(name:'Administrative', display: true ,custom: false, add_edit_order_items: true, import_orders: true, change_order_status: true,  create_edit_notes: false,
              view_packing_ex: true,
              delete_products: true,
              import_products: true,
              create_edit_notes: true,
              add_edit_products: true,
              add_edit_users: true,
              access_orders: true,
              access_products: true,
              access_scanpack: false,
              access_settings: true,
              edit_general_prefs: true,
              add_edit_stores: true,
              create_backups: true,
              restore_backups: true,
              edit_product_location: true,
              edit_product_quantity: true,
              edit_shipping_settings: true,
              edit_visible_services: true,
              add_edit_shortcuts: true,
              add_edit_dimension_presets:true 
            )
            end
        end
      end
    end
  end
  