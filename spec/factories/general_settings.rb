FactoryGirl.define do
  factory :general_setting do
    inventory_tracking false
    low_inventory_alert_email false
    low_inventory_email_address "MyString"
    hold_orders_due_to_inventory false
    conf_req_on_notes_to_packer "MyString"
    send_email_for_packer_notes "MyString"
    email_address_for_packer_notes "MyString@test.com"
  end
end

FactoryGirl.define do
  factory :low_inventory_alert_settings, :class => GeneralSetting do
    inventory_tracking true 
    low_inventory_alert_email true
    low_inventory_email_address "test@example.com" 
    hold_orders_due_to_inventory nil
    conf_req_on_notes_to_packer "never" 
    send_email_for_packer_notes "never"
    email_address_for_packer_notes nil 
    default_low_inventory_alert_limit 1
    send_email_on_mon true
    send_email_on_tue true 
    send_email_on_wed true
    send_email_on_thurs true
    send_email_on_fri true
    send_email_on_sat true 
    send_email_on_sun true 
    time_to_send_email "2016-07-06 10:53:00"
  end
end
