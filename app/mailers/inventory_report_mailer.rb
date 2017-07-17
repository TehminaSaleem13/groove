class InventoryReportMailer < ActionMailer::Base
	  default from: "app@groovepacker.com"

	  def manual_inventory_report(id, tenant)
	  	Apartment::Tenant.switch tenant
	  	@product_inv_setting = InventoryReportsSetting.last
	    selected_reports = ProductInventoryReport.where("id in (?)", id)
	    start_time = @product_inv_setting.start_time.strftime("%m-%d-%Y") rescue nil
	    end_time = @product_inv_setting.end_time.strftime("%m-%d-%Y") rescue nil
	    headers = "DATE_RANGE,SKU,PRODUCT_NAME,QTY_SCANNED_IN_RANGE, QTY_SCANNED_LAST_90, CURRENT_AVAILABLE,CURRENT_QOH, PROJECTED_DAYS_REMAINING, CATEGORY, LOCATION1, LOCATION2, LOCATION3\n"
	    selected_reports.each do |report|	
	    	products = get_products(report)
	    	if !report.type
		    	file_name = "inventory_report_#{Time.now.strftime("%y%m%d_%H%M%S")}.csv"
			    File.open("public/#{file_name}", 'a+', {force_quotes: true}) do |csv|	
			    	products.each_with_index do |pro, index|			    		
				    	pro_orders = pro.order_items.map(&:order)
				    	inv = pro.product_inventory_warehousess
							orders = Order.where("id IN (?) and scanned_on >= ? and scanned_on <= ?",pro_orders.map(&:id), @product_inv_setting.try(:start_time).try(:beginning_of_day), @product_inv_setting.try(:end_time).try(:end_of_day)) rescue 0
				      orders_90 = Order.where("id IN (?) and scanned_on >= ?",pro_orders.map(&:id), Time.now-90.days) rescue 0
			      	csv << headers if index.eql? 0 
			      	row = ""
			      	available_inv = inv.map(&:available_inv).sum 
			      	quantity_on_hand = inv.map(&:quantity_on_hand).sum
			      	projected_days_remaining = quantity_on_hand.to_f/(orders_90.count.to_f/90) rescue 0
			      	row << "#{start_time} to #{end_time},#{pro.primary_sku},#{pro.name.gsub(',',' ')},#{orders.try(:count)},#{orders_90.try(:count)},#{available_inv},#{quantity_on_hand},#{projected_days_remaining},#{pro.product_cats[0].try(:category)},#{inv[0].try(:location_primary)},#{inv[0].try(:location_secondary)},#{inv[0].try(:location_tertiary)}\n"
			      	csv << row 
			      end
			    end
			    attachments[file_name] = File.read("public/#{file_name}")
		     	subject = "Inventory Projection Report"
		      email = @product_inv_setting.report_email
		      mail to: email, subject: subject
		    else
		    	flag = true
		    	auto_inventory_report(flag, report, tenant)
		    end
	    end
	  end

	  def auto_inventory_report(flag, report=nil, tenant)
	  	Apartment::Tenant.switch tenant if tenant.present?
	  	reports = report.present? ? [report] : ProductInventoryReport.where(scheduled: true)
	  	@product_inv_setting = InventoryReportsSetting.last
	  	headers = "DATE_FOR_DAILY_TOTAL,SKU,PRODUCT_NAME,DAILY_SKU_QTY\n"
	  	reports.each do |report|
	  		file_name = "sku_per_day_report_#{Time.now.strftime("%y%m%d_%H%M%S")}.csv"
	  		products = get_products(report)
	  		File.open("public/#{file_name}", 'a+', {force_quotes: true}) do |csv|	
	  			csv << headers 
	  			days = get_days(flag)
		    	days.times do |i| 	
		    		products.each do |pro|
		    			orders = pro.order_items.map(&:order)
		    			if flag==true
			    			orders = Order.where("id IN (?) and scanned_on >= ? and scanned_on <= ?",orders.map(&:id), (@product_inv_setting.start_time+"#{i}".to_i.days).beginning_of_day, (@product_inv_setting.start_time+"#{i}".to_i.days).end_of_day)
			    			date = (@product_inv_setting.start_time+"#{i}".to_i.days).strftime("%m/%d/%y")
			    		else
			    			orders = Order.where("id IN (?) and scanned_on >= ? and scanned_on <= ?",orders.map(&:id), (DateTime.now-"#{i}".to_i.days).beginning_of_day, (DateTime.now-"#{i}".to_i.days).end_of_day)
			    			date = (DateTime.now.beginning_of_day-"#{i}".to_i.days).strftime("%m/%d/%y")
		    			end
		    			row = ""
		    			row << "#{date},#{pro.primary_sku},#{pro.name.gsub(',',' ')},#{orders.count}\n"
		    			csv << row 
		    		end
		    	end
		    end
		    attachments[file_name] = File.read("public/#{file_name}")
	     	subject = "Sku Per Day Report"
	      email = @product_inv_setting.report_email
	      mail to: email, subject: subject
	  	end
	  end

	  def get_days(flag)
	  	if flag==true
				days = (@product_inv_setting.end_time.to_date - @product_inv_setting.start_time.to_date).to_i
				days = 0 if days<0 			
			else
				days = @product_inv_setting.report_days_option
			end
			days
	  end

	  def get_products(report)
	  	if (report.name == "All_Products_Report") && report.is_locked
	  		products = Product.all
	  	elsif  (report.name == "Active_Products_Report") && report.is_locked
	  		products = Product.where(status: "active")
	  	else
	    	products = report.products
	    end
	    products
	  end
end
