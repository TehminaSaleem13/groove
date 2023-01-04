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
        begin
          Apartment::Tenant.switch! tenant.name
          Time.use_zone(GeneralSetting.new_time_zone) do
            product_inv_setting = InventoryReportsSetting.last
            # gn_setting = GeneralSetting.first
            #  time = product_inv_setting.time_to_send_report_email - gn_setting.time_zone.to_i.seconds
            time = product_inv_setting.time_to_send_report_email
            #  time -= 3600 unless gn_setting.dst
            # day = time.strftime('%A')
            current_day = Time.current.strftime("%A")
            result = false
            scheduled_report = ProductInventoryReport.where(scheduled: true)
            unless scheduled_report.empty?
              if product_inv_setting.send_email_on_sun == true && product_inv_setting.send_email_on_sun && current_day == "Sunday"
                result = true
              elsif product_inv_setting.send_email_on_mon == true && product_inv_setting.send_email_on_mon && current_day == "Monday"
                result = true
              elsif product_inv_setting.send_email_on_tue == true && product_inv_setting.send_email_on_tue && current_day == "Tuesday"
                result = true
              elsif product_inv_setting.send_email_on_wed == true && product_inv_setting.send_email_on_wed && current_day == "Wednesday"
                result = true
              elsif product_inv_setting.send_email_on_thurs == true && product_inv_setting.send_email_on_thurs && current_day == "Thursday"
                result = true
              elsif product_inv_setting.send_email_on_fri == true && product_inv_setting.send_email_on_fri && current_day == "Friday"
                result = true
              elsif product_inv_setting.send_email_on_sat == true && product_inv_setting.send_email_on_sat && current_day == "Saturday"
                result = true
              end
            end
            tenant_name = tenant.name
            InventoryReportMailer.delay(run_at: time.strftime('%H:%M:%S'), queue: "schedule_inventory_report_#{tenant_name}", priority: 95).auto_inventory_report(false, nil, nil, tenant_name) if result == true
          end
        rescue StandardError
        end
      end
    end
    exit(1)
  end
end
