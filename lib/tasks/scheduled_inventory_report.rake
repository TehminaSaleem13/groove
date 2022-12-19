# frozen_string_literal: true

namespace :doo do
  desc 'Schedule inventory email'
  task schedule_inventory_report: :environment do
    if $redis.get('schedule_inventory_report').blank?
      $redis.set('schedule_inventory_report', true)
      $redis.expire('schedule_inventory_report', 5400)
      failed_tenant = []
      tenants = Tenant.order(:name)
      tenants.each do |tenant|
        Apartment::Tenant.switch! tenant.name
        Time.use_zone(GeneralSetting.new_time_zone) do
          product_inv_setting = InventoryReportsSetting.last
          # gn_setting = GeneralSetting.first
          #  time = product_inv_setting.time_to_send_report_email - gn_setting.time_zone.to_i.seconds
          time = product_inv_setting.time_to_send_report_email
          #  time -= 3600 unless gn_setting.dst
          day = time.strftime('%A')
          result = false
          if day == 'Sunday' && product_inv_setting.send_email_on_sun
            result = true
          elsif day == 'Monday' && product_inv_setting.send_email_on_mon
            result = true
          elsif day == 'Tuesday' && product_inv_setting.send_email_on_tue
            result = true
          elsif day == 'Wednesday' && product_inv_setting.send_email_on_wed
            result = true
          elsif day == 'Thursday' && product_inv_setting.send_email_on_thurs
            result = true
          elsif day == 'Friday' && product_inv_setting.send_email_on_fri
            result = true
          elsif day == 'Saturday' && product_inv_setting.send_email_on_sat
            result = true
          end
          tenant_name = tenant.name
          InventoryReportMailer.delay(run_at: time.strftime('%H:%M:%S'), queue: "schedule_inventory_report_#{tenant_name}", priority: 95).auto_inventory_report(false, nil, nil, tenant_name) if result == true
        end
      rescue StandardError
      end
    end
    exit(1)
  end
end
