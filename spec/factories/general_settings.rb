# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :general_setting do
    inventory_tracking false
    low_inventory_alert_email false
    low_inventory_email_address "MyString"
    hold_orders_due_to_inventory false
    conf_req_on_notes_to_packer "MyString"
    send_email_for_packer_notes "MyString"
    email_address_for_packer_notes "MyString"
  end
end
