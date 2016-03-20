namespace :mr do
  desc "Generates Monthly Scanned Report of Each Tenant"

  task :generate_report => :environment do
    tenants = Tenant.all
    puts tenants.count.to_s
    require 'csv'
    CSV.open("#{Rails.root}/public/csv/export.csv", "w") do |csv|
      tenants.each do |tenant|
        csv << [tenant.name]
        headers = ['begin_time', 'end_time', 'order_scan_count']
        csv << headers
        @subscription = Subscription.where(tenant_name: tenant.name, is_active: 1).first
        next unless @subscription
        created_at = @subscription.created_at
        if created_at < Time.now - 1.month
          while created_at < Time.now - 1.month
            created_at += 1.month
          end
        end
        Apartment::Tenant.switch(tenant.name)
        for i in 1..5
          data = []
          created_at -= 1.month
          begin_time = created_at.beginning_of_day
          end_time = (created_at + 1.month).end_of_day
          data.push(begin_time.strftime("%d-%b-%Y"))
          data.push(end_time.strftime("%d-%b-%Y"))
          count = Order.where(status: 'scanned').where(scanned_on: begin_time..end_time).count.to_s
          data.push(count)
          csv << data
        end
        csv << []
      end
    end
    exit(1)
  end
end
