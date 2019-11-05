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
    store = Store.find_by_id(params["store_id"])
    begin
      store = Store.find_by_id(params["store_id"])
      @tenant_name = Apartment::Tenant.current
      summary = CsvImportSummary.where("log_record IS NOT NULL and created_at > ?", Time.now() - 30.days).reverse!
      lines = summary.map(&:log_record).uniq
      if store.store_type == "CSV"
        headers = ["Time Stamp Tenant TZ", "Time Stamp UTC", "Filename","Tenant", " Orders in file " , "New_orders_imported", "Existing orders updated", "Existing orders skipped", "Orders before import", "Orders after import", "Check E=F+G+H", " Check J=F+I"]
        data = CSV.generate do |csv|
          csv << headers if csv.count.eql? 0
          lines.each do |r| 
            y = JSON.parse r
            if y["Tenant"] == @tenant_name && y["Type"].nil?
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
      else
        headers = ["Time Stamp Tenant TZ", "Time Stamp UTC", "Type", "Order Create Date", "Order Modified Date","Order Status (the status in the OrderManager)", "Order Status Settings in GP" , "Order Date Settings in GP"]
        data = CSV.generate do |csv|
          csv << headers if csv.count.eql? 0
          lines.each do |r| 
            y = JSON.parse r
            if y["Tenant"] == @tenant_name && y["Type"] != nil
              csv << [y["Timestamp of the OD import (in tenants TZ)"], y["Timestamp of the OD import (UTC)"] ,y["Type"],y["Order Create Date"], y["Order Modified Date"], y["Order Status (the status in the OrderManager)"], y["Order Status Settings"], y["Order Date Settings"]]
            end
          end
        end
      end  
      url = GroovS3.create_public_csv(@tenant_name, 'order_import_summary',Time.now.to_i, data).url
      render json: {url: url}
    rescue Exception => e
      Rollbar.error(e, e.message)
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
      if store.store_type == "Shipstation API 2"
        cred.quick_import_last_modified = nil 
      end
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

  def get_last_modified
    result = {}
    cred = ShipstationRestCredential.find_by_store_id(params["store_id"])
    time_zone = GeneralSetting.last.time_zone.to_i
    if cred.present?
      if cred.quick_import_last_modified.nil?
        result[:last_imported_at] =  (Time.now.utc - 5.day)  + time_zone 
      else
        result[:last_imported_at] =  cred.quick_import_last_modified.to_time + time_zone 
      end
    
      result[:current_time] = Time.now.utc + time_zone
    end
    render json: result
  end

  def get_import_details
    import_item = ImportItem.where(store_id: params["store_id"]).last
    unless import_item.nil?
      result = import_item.get_import_item_info(params["store_id"])
    else
      result = { status: false }
    end  
    render json: result
  end
end

