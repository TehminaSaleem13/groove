module ProductsHelper

  require 'barby'
  require 'barby/barcode/code_128'
  require 'barby/outputter/png_outputter'

  require 'mws-connect'
  # requires a product is created with appropriate seller sku
  def import_amazon_product_details(store_id, product_sku, product_id)
    ProductsService::AmazonImport.call(store_id, product_sku, product_id)
  end

  def updatelist(product, var, value, current_user = nil)
    ProductsService::UpdateList.call(product, var, value, current_user)
  end

  # gets called from orders helper
  def import_ebay_product(itemID, sku, ebay, credential)
    ProductsService::EbayImport.call(itemID, sku, ebay, credential)
  end

  def generate_barcode(barcode_string)
    barcode = Barby::Code128B.new(barcode_string)
    outputter = Barby::PngOutputter.new(barcode)
    outputter.margin = 0
    blob = outputter.to_png # Raw PNG data
    image_name = Digest::MD5.hexdigest(barcode_string)
    File.open("#{Rails.root}/public/images/#{image_name}.png",
              'w') do |f|
      f.write blob
    end
    image_name
  end

  def list_selected_products(params, include_association = true)
    ProductsService::ListSelectedProducts.call(params, include_association)
  end

  def do_getproducts(params)
    ProductsService::FindProducts.call(params)
  end

  def do_search(params, results_only = true)
    ProductsService::SearchProducts.call(params, results_only)
  end

  def self.products_csv(products, csv, bulk_actions_id = nil, bulk_csv = nil)
    ProductsService::GenerateCSV.call(products, csv, bulk_actions_id, bulk_csv)
  end

  def make_product_intangible(product)
    scan_pack_settings = ScanPackSetting.all.first
    return unless scan_pack_settings.intangible_setting_enabled &&
                  scan_pack_settings.intangible_string.present?
    intangible_strings = scan_pack_settings.intangible_string.strip.split(',')
    intangible_strings.each do |string|
      next unless (product.name.downcase.include?(string.downcase)) ||
                  (product.primary_sku.downcase.include?(string.downcase))
      product = Product.find(product.id, :readonly => false)
      product.is_intangible = true
      product.save 
      break
    end
  end

  def replace_product(product, sku)
    scan_pack_settings = ScanPackSetting.all.first
    intangible_strings = scan_pack_settings.intangible_string.downcase.strip.split(',')
    coupan_product = nil
    intangible_strings.each do |string|
      if product.downcase.include?(string) || sku.downcase.include?(string)
        coupan_product = Product.joins(:product_skus).where("product_skus.sku =  ?", "GP Coupon").readonly(false).last
        if coupan_product.nil?
          coupan_product  =  Product.new
          coupan_product.name = "GP Coupon"
          coupan_product.store_id = 1
        end   
        coupan_product.is_intangible =  true
        coupan_product.status=  "active"
        coupan_product.save
        coupan_product.product_skus.create(sku: "GP Coupon") if coupan_product.present?
        break
      end  
    end
    coupan_product
  end

  def check_for_replace_product
    scan_pack_settings = ScanPackSetting.all.first
    scan_pack_settings.intangible_setting_enabled && scan_pack_settings.intangible_string.present? && scan_pack_settings.replace_gp_code
  end

  def get_weight_format(weight_format)
    if weight_format.present?
      return weight_format
    else
      return GeneralSetting.get_product_weight_format
    end
  end

  def get_barcode_slip_template
    g_setting = GeneralSetting.last
    g_setting.show_primary_bin_loc_in_barcodeslip ? "generate_barcode_slip_with_binloc.html.erb" 
                                                  : 'generate_barcode_slip.html.erb'
  end

  def generate_report(ids)
    tenant = Apartment::Tenant.current
    InventoryReportMailer.delay.manual_inventory_report(ids, tenant)
    # InventoryReportMailer.manual_inventory_report(ids).deliver
  end

  def update_inv_record(data, params)
    selected_ids = data["selected"] || data["selected_id"]
    products = data["select_toggle"] ? Product.all : Product.where("id in (?)", selected_ids)
    id = data["report_id"] || params["data"]["id"]
    report = id.present? ? ProductInventoryReport.find(id) : ProductInventoryReport.new
    report_name = data["report_name"] || data["name"]
    report.name = report_name.present? ? report_name : "Default Report"
    report.scheduled = data["scheduled"] 
    report.type = data["type"] 
    report.products = products
    report.save
    @result["status"] = true
    @result
  end

end
