namespace :doo do
  desc "Create CSV and save to S3 and email"

  task :export_import_log => :environment do
	[1, 2].each do |order|   	
	    ["unitedmedco", "sunlessinc", "janinetait", "brokencoast"].each do |tenant|
	    	file_response = File.read("#{Rails.root}/log/qty_csv_import_#{order}_#{tenant}.log") rescue nil
		    if file_response.present?	
		    	file_name = "#{tenant}_import_log_#{Time.now.strftime("%Y_%d_%m")}"
		    	GroovS3.create_csv(tenant, file_name, 1, file_response, :public_read)
		    	url = GroovS3.find_csv(tenant, file_name, 1).url
		    	import = (order == "1" ? "Import" : "ReImport")
		    	CsvExportMailer.import_log(url, tenant, import).deliver
		    end
	    end
	end
	["shipstation_order_import", "shipstation_tag_order_import"].each do |log_name|
		["lairdsuperfood", "gunmagwarehouse"].each do |tenant|
			file_response = File.read("#{Rails.root}/log/#{log_name}_#{order}_#{tenant}.log") rescue nil
			if 	file_response.present?
				file_name = "#{tenant}_#{log_name}_#{Time.now.strftime("%Y_%d_%m")}"	
				GroovS3.create_csv(tenant, file_name, 1, file_response, :public_read)
		    	url = GroovS3.find_csv(tenant, file_name, 1).url
		    	CsvExportMailer.import_log(url, tenant, log_name.gsub("_", " ")).deliver
		    end
	    end
	end
    exit(1)
  end  
end
