# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InventoryReportsSetting, type: :model do
  it 'runs scheduled_inv_report callback' do
    GeneralSetting.first_or_create
    export_setting = described_class.first_or_create

    export_setting.attributes = { time_to_send_report_email: Time.current, report_email: 'kcpatel006@gmail.com' }
    export_setting.save
  end
end
