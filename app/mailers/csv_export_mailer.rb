# frozen_string_literal: true

class CsvExportMailer < ActionMailer::Base
  default from: 'app@groovepacker.com'

  def send_s3_object_url(filename, object_url, tenant)
    Apartment::Tenant.switch!(tenant)
    general_setting = GeneralSetting.all.first
    recipients = [general_setting.admin_email]
    user_emails = begin
                    general_setting.export_csv_email.split(',')
                  rescue StandardError
                    []
                  end
    user_emails.each do |email|
      recipients << email
    end
    @filename = filename
    @object_url = object_url
    subject = "GroovePacker #{tenant} Backup successful."
    mail to: recipients, subject: subject if recipients.compact.present?
  end

  def send_daily_packed(object_url, tenant)
    Apartment::Tenant.switch!(tenant)
    @object_url = object_url
    # general_setting = GeneralSetting.all.first
    # recipients = [general_setting.email_address_for_packer_notes]
    recipients = [ExportSetting.first.daily_packed_email]
    subject = "Daily Packed % Report for #{tenant}"
    file_name = "#{tenant}_#{Time.current.to_i}.csv"
    attachments[file_name] = begin
                               Net::HTTP.get(URI.parse(object_url))
                             rescue StandardError
                               nil
                             end
    mail to: recipients, subject: subject
  end

  def send_s3_product_object_url(filename, object_url, tenant, no_product)
    Apartment::Tenant.switch!(tenant)
    general_setting = GeneralSetting.all.first
    recipients = [general_setting.email_address_for_packer_notes]
    @no_product = 'Empty' if no_product
    @filename = filename
    @object_url = object_url
    subject = 'Products Export Report.'
    mail to: recipients, subject: subject
  end

  def unscanned_csv(filename, tenant)
    Apartment::Tenant.switch!(tenant)
    attachments[filename] = File.read("public/#{filename}")
    mail to: ENV['UNSCANNED_ORDERS_EMAILS'], subject: 'GroovePacker Unscanned Export Report'
  end

  def product_restore(tenant)
    Apartment::Tenant.switch!(tenant)
    recipients = begin
                   GeneralSetting.all.first.export_csv_email.split(',')
                 rescue StandardError
                   []
                 end
    mail to: recipients, subject: 'GroovePacker Product Restore Is Completed'
  end

  def send_s3_broken_image_url(url, tenant)
    recipients = begin
                   GeneralSetting.all.first.email_address_for_packer_notes.split(',')
                 rescue StandardError
                   []
                 end
    @url = url
    mail to: recipients, subject: "[#{tenant}] Product Broken Images CSV" if recipients.present?
  end

  def send_fix_shopify_product_images(tenant)
    recipients = begin
                   GeneralSetting.all.first.email_address_for_packer_notes.split(',')
                 rescue StandardError
                   []
                 end
    mail to: recipients, subject: "[#{tenant}] Fix Broken Images" if recipients.present?
  end

  def send_re_associate_all_products(tenant, data = {})
    @data = data
    recipients = begin
                   GeneralSetting.all.first.email_address_for_packer_notes.split(',')
                 rescue StandardError
                   []
                 end
    mail to: recipients, subject: "[#{tenant}] Re-associate All Products" if recipients.present?
  end

  def send_push_pull_inventories_products(tenant, type)
    @type = type
    recipients = begin
                   GeneralSetting.all.first.email_address_for_packer_notes.split(',')
                 rescue StandardError
                   []
                 end
    mail to: recipients, subject: type == 'push_inv' ? "[#{tenant}] Push Inventory Products" : "[#{tenant}] Pull Inventory Products" if recipients.present?
  end

  def send_s3_export_product_url(url, tenant)
    recipients = begin
                   GeneralSetting.all.first.email_address_for_packer_notes.split(',')
                 rescue StandardError
                   []
                 end
    @url = url
    mail to: recipients, subject: "[#{tenant}] Product Export CSV" if recipients.present?
  end

  def import_log(url, tenant, order)
    @url = url
    mail to: ENV['PRODUCTS_IMPORT_EMAILS'], subject: "[#{tenant}] #{order} CSV Log"
  end

  def export_scanned_time_log(url)
    @url = url
    mail to: ENV['PRODUCTS_IMPORT_EMAILS'], subject: 'Export log with fetching time'
  end

  def send_csv(url)
    @url = url
    mail to: ['groovepacker@gmail.com', 'groovepackerservice@gmail.com', 'kcpatel006@gmail.com'], subject: "[#{ENV['RAILS_ENV']}] Activity Log"
  end

  def send_bulk_record_csv(url,current_tenant)
    @tenant = current_tenant
    @url = url
    mail to: ['groovepacker@gmail.com', 'groovepackerservice@gmail.com', 'kcpatel006@gmail.com'], subject: "Order & Product Removal Report [#{@tenant}]"
  end

  def send_duplicates_order_info(tenant, dup_order_increment_ids, dup_order_ids)
    @tenant = tenant
    @dup_order_increment_ids = dup_order_increment_ids
    @dup_order_ids = dup_order_ids
    mail to: 'kcpatel006@gmail.com, groovepacker@gmail.com', subject: "[#{@tenant}]  orders are duplicate"
  end
end
