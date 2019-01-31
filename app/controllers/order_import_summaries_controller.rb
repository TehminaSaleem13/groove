class OrderImportSummariesController < ApplicationController
  before_filter :groovepacker_authorize!, except: [:download_summary_details]
  
  def update_display_setting
    orderimportsummary = OrderImportSummary.last
    if orderimportsummary.present?
      orderimportsummary.display_summary = params[:flag]
      orderimportsummary.save
    end
    render json: {status: true}
  end

  def update_order_import_summary
    orderimportsummary = OrderImportSummary.first
    if orderimportsummary.present?
      orderimportsummary.status = "not_started"
      orderimportsummary.save
    end
    render json: {status: true}
  end

  def download_summary_details
    #require 'open-uri'
    begin
      @tenant_name = Apartment::Tenant.current
      #url = ENV['S3_BASE_URL']+'/'+"#{Apartment::Tenant.current}"+'/log/'+"import_order_info_#{Apartment::Tenant.current}.log"
      #lines = open(url).read
      summary = CsvImportSummary.where("log_record IS NOT NULL and created_at > ?", Time.now() - 30.days)
      lines = summary.map(&:log_record).uniq
      
      headers = ["Time Stamp Tenant TZ", "Time Stamp UTC", "Filename","Tenant", " Orders in file " , "New_orders_imported", "Existing orders updated", "Existing orders skipped", "Orders before import", "Orders after import", "Check C=D+E+F", "Check H=D+G"]
      data = CSV.generate do |csv|
        csv << headers if csv.count.eql? 0
        lines.each do |r| 
          #y = eval r.gsub(/[\"]/, "'")
          y = JSON.parse r
          if y["Tenant"] == @tenant_name
            if y['Orders_in_file'] ==  y['New_orders_imported'] + y['Existing_orders_updated'] + y['Existing_orders_skipped']
              check_1 = 'YES'
            else
              check_1 ='NO'
            end  
            
            if y['Orders_in_GroovePacker_after_import'] == y['New_orders_imported'] + y['Orders_in_GroovePacker_before_import']
              check_2 = 'YES'
            else
              check_2 = 'No'
            end
            csv << [y["Time_Stamp_Tenant_TZ"], y["Time_Stamp_UTC"] ,y["Name_of_imported_file"], y["Tenant"], y["Orders_in_file"], y["New_orders_imported",], y["Existing_orders_updated"], y["Existing_orders_skipped",], y["Orders_in_GroovePacker_before_import",], y["Orders_in_GroovePacker_after_import"], "#{check_1}", "#{check_2}"]
          end
        end
      end
      url = GroovS3.create_public_csv(@tenant_name, 'order_import_summary',Time.now.to_i, data).url
      render json: {url: url}
    rescue Exception => e
      logger = Logger.new("#{Rails.root}/log/download_summary_details_#{Apartment::Tenant.current}.log")
      logger.info(e)
    end
  end

  def fix_imported_at
    store = Store.find_by_id(params["store_id"])
    if store.store_type == "BigCommerce"
      cred = BigCommerceCredential.find_by_store_id(params["store_id"])
    elsif store.store_type == "ShippingEasy"
      cred = ShippingEasyCredential.find_by_store_id(params["store_id"])
    elsif store.store_type == "Shipstation API 2"
      cred = ShipstationRestCredential.find_by_store_id(params["store_id"])
    elsif store.store_type == "Teapplix"
      cred = TeapplixCredential.find_by_store_id(params["store_id"])
    elsif store.store_type == "Magento"
      cred = MagentoCredentials.find_by_store_id(params["store_id"])
    elsif store.store_type == "Shopify"
      cred = ShopifyCredential.find_by_store_id(params["store_id"])
    elsif store.store_type == "Magento API 2"
      cred = MagentoRestCredential.find_by_store_id(params["store_id"])
    elsif store.store_type == "Amazon"
      cred = AmazonCredentials.find_by_store_id(params["store_id"])
    end
    if cred   
      cred.last_imported_at = nil
      cred.quick_import_last_modified = nil if store.store_type == "Shipstation API 2"
      cred.save
    end
    render json: {status: true}
  end

  def delete_import_summary
    store = Store.find_by_id(params["store_id"])
    i = ImportItem.where(store_id: store.id).last
    if !i.order_import_summary.nil?
      i.order_import_summary.destroy
    end
    
    render json: {status: true}
  end

end

