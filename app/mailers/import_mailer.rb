# frozen_string_literal: true

class ImportMailer < ActionMailer::Base
  default from: 'app@groovepacker.com'

  def failed(import_exception)
    @import_exception = import_exception
    subject = if @import_exception.nil?
                'Import failed'
              else
                "[#{@import_exception[:tenant]}] [#{Rails.env}] Import failed"
              end
    mail to: ENV['FAILED_IMPORT_NOTIFICATION_EMAILS'], subject: subject
  end

  def import_hung(tenant, import_item)
    @file_name = $redis.get("#{tenant}_csv_filename")
    @file_name = $redis.get("file_name_#{tenant}") if @file_name.nil?
    @tenant = tenant
    @import = import_item
    subject = "[#{@tenant}] [#{Rails.env}] Import Hung"
    mail to: ENV['FAILED_IMPORT_NOTIFICATION_EMAILS'], subject: subject
  end

  def failed_imports(tenant, import_items)
    @tenant = tenant
    @import_items = import_items
    subject = "[#{@tenant}] [#{Rails.env}] Import Failed"
    mail to: ENV['FAILED_IMPORT_NOTIFICATION_EMAILS'], subject: subject
  end

  def shipstation_unauthorized(import_exception, query, header, end_point)
    @end_point = end_point
    @header = header
    @query = query
    @import_exception = import_exception
    subject = if @import_exception.nil?
                'Import failed'
              else
                "[#{Apartment::Tenant.current}] [#{Rails.env}] SS Failed request data"
              end
    mail to: ENV['SHIPSTATION_IMPORT_FAILURE_EMAILS'], subject: subject
  end

  def send_products_import_email(products_count, credential)
    @products_count = products_count
    @credential = credential
    @current_tenant = Apartment::Tenant.current
    subject = "[#{@current_tenant}] [#{Rails.env}] initiated products import for #{@products_count} products"
    mail to: ENV['PRODUCTS_IMPORT_EMAILS'], subject: subject
  end

  def send_products_import_complete_email(products_count, result, credential)
    system_notifications_email = begin
                                   (GeneralSetting.first.email_address_for_packer_notes || '')
                                 rescue StandardError
                                   ''
                                 end
    @products_count = products_count
    @credential = credential
    @result = result
    @current_tenant = Apartment::Tenant.current
    subject = "[#{@current_tenant}] [#{Rails.env}] products import for Store: #{@credential.store.name} is complete"
    mail to: system_notifications_email.to_s, bcc: ENV['PRODUCTS_IMPORT_COMPLETE_EMAILS'], subject: subject
  end

  def order_skipped(file_name, skip_count, store_id, skip_ids)
    @file_name = file_name
    @skip_count = skip_count
    @skip_ids = skip_ids
    @store = Store.find_by_id(store_id)
    @current_tenant = Apartment::Tenant.current
    subject = 'Import order skipped'
    mail to: ENV['SKIPPED_IMPORT_NOTIFICATION_EMAILS'], subject: subject
  end

  def order_information(file_name, item_hash)
    tenant = Apartment::Tenant.current
    @file_name = file_name
    @item_hash = item_hash
    subject = "[#{tenant}] Order CSV Failure Report "
    mail to: ENV['FAILED_IMPORT_NOTIFICATION_EMAILS'], subject: subject
  end

  def duplicate_order_info(tenant, value, data)
    @tenant = tenant
    @value = value
    @data = data
    subject = "[#{@tenant}] #{@value} are duplicate "
    mail to: 'kcpatel006@gmail.com', subject: subject
  end

  def check_old_orders(tenant, data)
    @tenant = tenant
    @data = data
    subject = "[#{@tenant}] check for old orders "
    mail to: 'kcpatel006@gmail.com', subject: subject
  end
end
