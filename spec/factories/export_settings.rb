# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :export_setting do
  end
end

FactoryGirl.define do
  factory :export_order_setting, :class => ExportSetting do
    auto_email_export true 
    time_to_send_export_email "2016-07-04 16:52:00" 
    last_exported "2016-04-07 01:51:44" 
    export_orders_option "on_same_day"
    order_export_type "include_all" 
    order_export_email "success@simulator.amazonses.com"
    start_time "2016-07-04 16:41:16" 
    end_time "2016-07-04 16:41:16" 
    manual_export false
  end
end
