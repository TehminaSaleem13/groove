# frozen_string_literal: true

class OrderImportSummariesController < ApplicationController
  before_action :groovepacker_authorize!, except: [:download_summary_details]

  def update_display_setting
    orderimportsummary = OrderImportSummary.last
    if orderimportsummary.present?
      orderimportsummary.display_summary = params[:flag]
      orderimportsummary.save
    end
    render json: { status: true }
  end

  def update_order_import_summary
    orderimportsummary = OrderImportSummary.first
    if orderimportsummary.present?
      orderimportsummary.status = 'not_started'
      orderimportsummary.save
    end
    render json: { status: true }
  end

  def download_summary_details
    store = Store.find_by_id(params['store_id'])
    begin
      @tenant_name = Apartment::Tenant.current
      summary = CsvImportSummary.where('log_record IS NOT NULL and created_at > ?', Time.current - 30.days).reverse
      lines = summary.map(&:log_record).uniq
      if store.store_type == 'CSV'
        data = prepare_csv_data(lines)
      else
        headers = ['Time Stamp Tenant TZ', 'Time Stamp UTC', 'Type', 'Order Create Date', 'Order Modified Date', 'Order Status (the status in the OrderManager)', 'Order Status Settings in GP', 'Order Date Settings in GP']
        data = CSV.generate do |csv|
          csv << headers if csv.count.eql? 0
          lines.each do |r|
            y = JSON.parse r
            if y['Tenant'] == @tenant_name && !y['Type'].nil?
              csv << [y['Timestamp of the OD import (in tenants TZ)'], y['Timestamp of the OD import (UTC)'], y['Type'], y['Order Create Date'], y['Order Modified Date'], y['Order Status (the status in the OrderManager)'], y['Order Status Settings'], y['Order Date Settings']]
            end
          end
        end
      end
      url = GroovS3.create_public_csv(@tenant_name, 'order_import_summary', Time.current.to_i, data).url.gsub('http:', 'https:')
      render json: { url: url }
    rescue Exception => e
      Rollbar.error(e, e.message, Apartment::Tenant.current)
    end
  end

  def prepare_csv_data(lines)
    headers = ['Time Stamp Tenant TZ', 'Time Stamp UTC', 'Filename', 'Tenant', ' Orders in file ', 'New_orders_imported', 'Existing orders updated', 'Existing orders skipped', 'Orders before import', 'Orders after import', 'Check E=F+G+H', ' Check J=F+I']
    data = CSV.generate do |csv|
      csv << headers if csv.count.eql? 0
      lines.each do |r|
        y = JSON.parse r
        next unless y['Tenant'] == @tenant_name && y['Type'].nil?

        condition_for_check_1 = y['Orders_in_file'] == (y['New_orders_imported'] + y['Existing_orders_updated'] + y['Existing_orders_skipped'])
        check_1 = condition_for_check_1 ? 'YES' : 'NO'

        condition_for_check_2 = y['Orders_in_GroovePacker_after_import'] == y['New_orders_imported'] + y['Orders_in_GroovePacker_before_import']
        check_2 = condition_for_check_2 ? 'YES' : 'No'

        csv << [y['Time_Stamp_Tenant_TZ'], y['Time_Stamp_UTC'], y['Name_of_imported_file'], y['Tenant'], y['Orders_in_file'], y['New_orders_imported',], y['Existing_orders_updated'], y['Existing_orders_skipped',], y['Orders_in_GroovePacker_before_import',], y['Orders_in_GroovePacker_after_import'], check_1.to_s, check_2.to_s]
      end
    end
    data
  end

  def fix_imported_at
    store = Store.find_by_id(params['store_id'])
    if store.store_type == 'BigCommerce'
      cred = BigCommerceCredential.find_by_store_id(params['store_id'])
    elsif store.store_type == 'ShippingEasy'
      cred = ShippingEasyCredential.find_by_store_id(params['store_id'])
    elsif store.store_type == 'Shipstation API 2'
      cred = ShipstationRestCredential.find_by_store_id(params['store_id'])
    elsif store.store_type == 'Teapplix'
      cred = TeapplixCredential.find_by_store_id(params['store_id'])
    elsif store.store_type == 'Magento'
      cred = MagentoCredentials.find_by_store_id(params['store_id'])
    elsif store.store_type == 'Shopify'
      cred = ShopifyCredential.find_by_store_id(params['store_id'])
    elsif store.store_type == 'Magento API 2'
      cred = MagentoRestCredential.find_by_store_id(params['store_id'])
    elsif store.store_type == 'Amazon'
      cred = AmazonCredentials.find_by_store_id(params['store_id'])
    end
    if cred
      cred.last_imported_at = nil
      cred.quick_import_last_modified = nil if store.store_type == 'Shipstation API 2'
      cred.save
    end
    render json: { status: true }
  end

  def delete_import_summary
    store = Store.find_by_id(params['store_id'])
    i = ImportItem.where(store_id: store.id).last
    i.order_import_summary&.destroy
    render json: { status: true }
  end

  def get_last_modified
    result = {}
    store = Store.find(params['store_id'])
    cred =  store.store_credential

    get_stores_last_import(result, store.store_type, cred, store) if cred.present?

    render json: result
  end

  def get_stores_last_import(result, store_type, cred, _store)
    if store_type == 'ShippingEasy'
      result[:last_imported_at] = begin
                                    cred.last_imported_at.strftime('%Y-%m-%d %H:%M:%S')
                                  rescue StandardError
                                    4.day.ago.strftime('%Y-%m-%d %H:%M:%S')
                                  end
    elsif store_type == %w[Shopify Shippo]
      result[:last_imported_at] = cred.last_imported_at.strftime('%Y-%m-%d %H:%M:%S') rescue 1.day.ago.strftime('%Y-%m-%d %H:%M:%S')
    else
      result[:last_imported_at] = cred.quick_import_last_modified_v2.nil? ? 1.day.ago.strftime('%Y-%m-%d %H:%M:%S') : cred.quick_import_last_modified_v2.strftime('%Y-%m-%d %H:%M:%S')
    end
    result[:current_time] = Time.current.strftime('%Y-%m-%d %H:%M:%S')
  end

  def get_import_details
    import_item = ImportItem.where(store_id: params['store_id'], status: 'in_progress').last
    result = if import_item.nil?
               { status: false, store_id: params['store_id'] }
             else
               import_item.get_import_item_info(params['store_id'])
             end
    render json: result
  end
end
