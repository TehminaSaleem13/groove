# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :role do
    name 'Scan & Pack User'
    display true
    custom false

    add_edit_order_items false
    import_orders true
    change_order_status false
    create_edit_notes false
    view_packing_ex false
    create_packing_ex false
    edit_packing_ex false

    delete_products false
    import_products false
    add_edit_products false

    add_edit_users false
    make_super_admin false

    access_scanpack true
    access_orders false
    access_products false
    access_settings false


    edit_general_prefs false
    edit_scanning_prefs false
    add_edit_stores false
    create_backups false
    restore_backups false
  end
end
