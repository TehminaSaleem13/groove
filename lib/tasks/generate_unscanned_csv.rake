namespace :doo do
  desc "Generate Unscanned CSV"

  task :unscanned_csv, [:tenant, :from, :upto] => [:environment] do |t, args|
    begin
    	Apartment::Tenant.switch!(args[:tenant])
      activities = OrderActivity.where("created_at>=? and created_at<=? and action Like ?" ,DateTime.now.in_time_zone - args[:from].to_i, DateTime.now.in_time_zone - args[:upto].to_i,  '%INVALID SCAN%')
      file_name = "#{activities.count}_unscanned_#{DateTime.now.in_time_zone}.csv"
      headers = "Order Id,Activity,User,Activity Time\n"
    	File.open("public/#{file_name}", 'a+', {force_quotes: true}) do |csv|
        csv << headers if csv.count.eql? 0
        activities.each do |activity|
          row = ""
          row << "#{activity.order_id}, #{activity.action}, #{activity.username}, #{activity.activitytime}\n"
          csv << row
        end
        csv << "\n\n Total Invalid Scans - , #{activities.count}"
      end
      CsvExportMailer.unscanned_csv(file_name, args[:tenant]).deliver
    rescue
    end
    exit(1)
  end
end
