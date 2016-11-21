class OrderImportSummariesController < ApplicationController
  before_filter :groovepacker_authorize!
  
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
    orderimportsummary.status = "not_started"
    orderimportsummary.save
    render json: {status: true}
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
    end
    if cred   
      cred.last_imported_at = nil
      cred.save
    end
    render json: {status: true}
  end

end

