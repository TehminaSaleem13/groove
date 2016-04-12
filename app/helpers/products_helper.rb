module ProductsHelper

  require 'barby'
  require 'barby/barcode/code_128'
  require 'barby/outputter/png_outputter'

  require 'mws-connect'
  # requires a product is created with appropriate seller sku
  def import_amazon_product_details(store_id, product_sku, product_id)
    ProductsService::AmazonImport.call(store_id, product_sku, product_id)
  end

  def updatelist(product, var, value)
    ProductsService::UpdateList.call(product, var, value)
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

  def list_selected_products(params)
    ProductsService::ListSelectedProducts.call(params)
  end

  def do_getproducts(params)
    ProductsService::FindProducts.call(params)
  end

  def do_search(params, results_only = true)
    ProductsService::SearchProducts.call(params, results_only)
  end

  def self.products_csv(products, csv, bulk_actions_id = nil)
    ProductsService::GenerateCSV.call(products, csv, bulk_actions_id)
  end

  def make_product_intangible(product)
    scan_pack_settings = ScanPackSetting.all.first
    return unless scan_pack_settings.intangible_setting_enabled &&
                  scan_pack_settings.intangible_string.present?
    intangible_strings = scan_pack_settings.intangible_string.strip.split(',')
    intangible_strings.each do |string|
      next unless (product.name.include?(string)) ||
                  (product.primary_sku.include?(string))
      product.is_intangible = true
      product.save
      break
    end
  end

  def get_weight_format(weight_format)
    if weight_format.present?
      return weight_format
    else
      return GeneralSetting.get_product_weight_format
    end
  end
end
