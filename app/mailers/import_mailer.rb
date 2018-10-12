class ImportMailer < ActionMailer::Base
  default from: "app@groovepacker.com"

  def failed(import_exception)
    @import_exception = import_exception
    if @import_exception.nil?
      subject = "Import failed"
    else
      subject = "[#{@import_exception[:tenant]}] [#{Rails.env}] Import failed"
    end
    mail to: ENV["FAILED_IMPORT_NOTIFICATION_EMAILS"], subject: subject
  end

  def import_hung(tenant, import_item)
    @file_name = $redis.get("#{tenant}_csv_filename")
    @tenant = tenant
    @import = import_item
    subject = "[#{@tenant}] [#{Rails.env}] Import Hung"
    mail to: ENV["FAILED_IMPORT_NOTIFICATION_EMAILS"] , subject: subject
  end

  def shipstation_unauthorized(import_exception, query, header, end_point)
    @end_point = end_point
    @header = header
    @query = query
    @import_exception = import_exception
    if @import_exception.nil?
      subject = "Import failed"
    else
      subject = "[#{Apartment::Tenant.current}] [#{Rails.env}] SS Failed request data"
    end
    mail to: ENV["SHIPSTATION_IMPORT_FAILURE_EMAILS"], subject: subject
  end

  def send_products_import_email(products_count, credential)
    @products_count = products_count
    @credential = credential
    @current_tenant = Apartment::Tenant.current
    subject = "[#{@current_tenant}] [#{Rails.env}] initiated products import for #{@products_count} products"
    mail to: ENV["PRODUCTS_IMPORT_EMAILS"], subject: subject
  end

  def send_products_import_complete_email(products_count, result, credential)
    system_notifications_email = (GeneralSetting.first.email_address_for_packer_notes || '') rescue ''
    @products_count = products_count
    @credential = credential
    @result = result
    @current_tenant = Apartment::Tenant.current
    subject = "[#{@current_tenant}] [#{Rails.env}] products import for Store: #{@credential.store.name} is complete"
    mail to: "#{system_notifications_email}", bcc: ENV["PRODUCTS_IMPORT_COMPLETE_EMAILS"], subject: subject
  end

  def order_skipped file_name, skip_count, store_id, skip_ids
    @file_name = file_name
    @skip_count = skip_count
    @skip_ids = skip_ids
    @store = Store.find_by_id(store_id)
    @current_tenant = Apartment::Tenant.current
    subject = "Import order skipped"
    mail to: ENV["SKIPPED_IMPORT_NOTIFICATION_EMAILS"], subject: subject
  end

  def order_information(file_name,item_hash)
    tenant = Apartment::Tenant.current
    @file_name = file_name
    @item_hash = item_hash
    subject = "[#{tenant}] Order CSV Failure Report "
    mail to: ENV["FAILED_IMPORT_NOTIFICATION_EMAILS"], subject: subject
  end

  def not_imported(file_name,order_in_file, new_order, update_order, skip_order, total_order, after_import )
    @file_name = file_name
    @order_in_file = order_in_file
    @new_order = new_order
    @update_order = update_order
    @skip_order = skip_order
    @total_order = total_order
    @after_import = after_import
    @current_tenant = Apartment::Tenant.current
    subject = "[#{@current_tenant}] Order CSV Import Summary Report "
    mail to: "kcpatel006@gmail.com", subject: subject
  end
end