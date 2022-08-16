# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExportSetting, type: :model do
  it 'should set start and end time' do
    export_setting = ExportSetting.new
    day_begin, end_time = export_setting.send(:set_start_and_end_time)
    expect(day_begin).should_not be_nil
    expect(end_time).should_not be_nil

    export_setting.time_to_send_export_email = Time.zone.parse('4:00')
    day_begin, end_time = export_setting.send(:set_start_and_end_time)

    expect(day_begin).should_not be_nil
    expect(end_time).should_not be_nil
  end

  it 'should run scheduled_export callback' do
    GeneralSetting.first_or_create
    export_setting = ExportSetting.first_or_create

    export_setting.attributes = { auto_email_export: true, time_to_send_export_email: Time.current, order_export_email: 'kcpatel006@gmail.com' }
    export_setting.save
  end

  it 'should export data when include partially scanned orders switch is on' do
    export_setting = ExportSetting.first_or_create

    export_setting.attributes = { auto_email_export: true, time_to_send_export_email: Time.current, order_export_email: 'kcpatel006@gmail.com', include_partially_scanned_orders: true}
    expect(export_setting.export_data ).to include('groove-order-export')

    export_setting.attributes = {order_export_type: "partially_scanned_only"}
    expect(export_setting.export_data ).to include('groove-order-export')

    export_setting.attributes = {order_export_type: "removed_only"}
    expect(export_setting.export_data ).to include('groove-order-export')
  end

  it 'should export data when include partially scanned orders switch is off' do
    export_setting = ExportSetting.first_or_create

    export_setting.attributes = { auto_email_export: true, time_to_send_export_email: Time.current, order_export_email: 'kcpatel006@gmail.com', include_partially_scanned_orders: false}
    expect(export_setting.export_data ).to include('groove-order-export')

    export_setting.attributes = {order_export_type: "partially_scanned_only"}
    expect(export_setting.export_data ).to include('groove-order-export')

    export_setting.attributes = {order_export_type: "removed_only"}
    expect(export_setting.export_data ).to include('groove-order-export')
  end
end
