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
    orderimportsummary.status = "not_started"
    orderimportsummary.save
    render json: {status: true}
  end

  def download_summary_details
    require 'wicked_pdf' 
    @tenant_name = Apartment::Tenant.current
    lines = File.open("#{Rails.root}/log/import_order_information.log").to_a
    @result = lines.last(64)
    action_view = do_get_action_view_object_for_html_rendering
    pdf_html = action_view.render :template => "order_import_summaries/download_summary_details.html.erb", :layout => nil, :locals => {:@result => @result}
    pdf_path = Rails.root.join('public', 'pdfs', "imported_order_information.pdf")
    doc_pdf = WickedPdf.new.pdf_from_string(
       pdf_html,
      :inline => true,
      :save_only => false,
      :orientation => 'Portrait',
      :page_height => '6in',
      :page_width => '4in',
      :margin => {:top => '1',
                  :bottom => '0',
                  :left => '2',
                  :right => '2'}
    )
    reader_file_path = Rails.root.join('public', 'pdfs', "imported_order_summary.pdf")
    File.open(reader_file_path, 'wb') do |file|
      file << doc_pdf
    end
    base_file_name = File.basename(pdf_path)
    pdf_file = File.open(reader_file_path)
    GroovS3.create_pdf(@tenant_name, base_file_name, pdf_file.read)
    pdf_file.close
    generate_url = ENV['S3_BASE_URL']+'/'+@tenant_name+'/pdf/'+base_file_name
    render json: {url: generate_url}
  end

  def do_get_action_view_object_for_html_rendering
    ActionView::Base.send(:define_method, :protect_against_forgery?) { false }
    action_view = ActionView::Base.new()
    action_view.view_paths = ActionController::Base.view_paths
    action_view.class_eval do
      include Rails.application.routes.url_helpers
      include ApplicationHelper
      include ProductsHelper
    end
    action_view
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

end

