# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :role do
    name 'Scan & Pack User'
    display true
    custom false

    add_edit_order_items true
    import_orders true
    change_order_status true
    create_edit_notes true
    view_packing_ex true
    create_packing_ex true
    edit_packing_ex true

    delete_products true
    import_products true
    add_edit_products true

    add_edit_users true
    make_super_admin true

    access_scanpack true
    access_orders true
    access_products true
    access_settings true


    edit_general_prefs true
    edit_scanning_prefs true
    add_edit_stores true
    create_backups true
    restore_backups true
  end
end
