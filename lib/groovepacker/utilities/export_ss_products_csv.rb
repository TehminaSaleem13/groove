# frozen_string_literal: true

class ExportSsProductsCsv
  include ProductsHelper
  def export_active_products(tenant_name)
    Apartment::Tenant.switch!(tenant_name)
    require 'csv'
    result = { 'status' => true, 'messages' => [] }
    products = Product.where(status: 'active')
    if products.empty?
      result['messages'] << 'There are no active products'
    else
      filename = 'groove-products-' + Time.current.to_s + '.csv'
      row_map = { SKU: '', Name: '', WarehouseLocation: '', WeightOz: '', Category: '', Tag1: '', Tag2: '', Tag3: '', Tag4: '', Tag5: '', CustomsDescription: '', CustomsValue: '', CustomsTariffNo: '', CustomsCountry: '', ThumbnailUrl: '', UPC: '', FillSKU: '', Length: '', Width: '', Height: '', UseProductName: '', Active: '' }
      data = CSV.generate do |csv|
        csv << row_map.keys

        products.each do |product|
          single_row = row_map.dup
          single_row[:SKU] = product.primary_sku
          single_row[:Name] = product.name
          single_row[:WarehouseLocation] = product.primary_warehouse.location_primary
          single_row = assign_single_row(product, single_row)
          # single_row[:Tag1] = ''
          # single_row[:Tag2] = ''
          # single_row[:Tag3] = ''
          # single_row[:Tag4] = ''
          # single_row[:Tag5] = ''
          # single_row[:CustomsDescription] = ''
          # single_row[:CustomsValue] = ''
          # single_row[:CustomsTariffNo] = ''
          single_row[:CustomsCountry] = product.order_items.first.order.country unless product.order_items.empty? || product.order_items.first.order.nil?
          # single_row[:ThumbnailUrl] = ''
          single_row[:UPC] = product.primary_barcode
          # single_row[:FillSKU] = ''
          # single_row[:Length] = ''
          # single_row[:Width] = ''
          # single_row[:Height] = ''
          # single_row[:UseProductName] = ''
          single_row[:Active] = product.is_active

          csv << single_row.values
        end
      end
     end
    generate_csv(result, data, filename, products)
  end

  def update_ss_product_locations(tenant_name, store_id)
    Apartment::Tenant.switch!(tenant_name)
    begin
      response = {}
      @store = Store.find(store_id)
      @credential = ShipstationRestCredential.find_by_store_id(@store.id)
      @client = Groovepacker::Stores::Handlers::ShipstationRestHandler.new(@store).build_handle[:store_handle]
      products = Product.includes(product_inventory_warehousess: [:inventory_warehouse]).where('store_id = ? AND status = ? AND updated_at > ?', store_id, 'active', @credential.last_location_push.present? ? @credential.last_location_push : 10.year.ago)
      response = @client.update_product_bin_locations(products) if products.present?
      @credential.update_attributes(last_location_push: Time.zone.now) if response['success']
    rescue StandardError => e
      puts e
    end
  end

  def export_broken_image(tenant, params)
    Apartment::Tenant.switch! tenant
    products = ProductsService::ListSelectedProducts.call(params, true)
    result = {}
    filter_products = []
    nil_images_products = Product.joins('LEFT OUTER JOIN product_images ON product_images.product_id = products.id').where('product_images.id IS NULL and products.id IN (?)', products.map(&:id))
    check_broken_images_products = products - nil_images_products
    check_broken_images_products.each do |product|
      filter_products << product if product.broken_image?
    end
    products = filter_products + nil_images_products
    result['filename'] = 'products-' + Time.current.to_s + '.csv'
    CSV.open("#{Rails.root}/public/csv/#{result['filename']}", 'w') do |csv|
      data = ProductsHelper.products_csv(products, csv)
      result['filename'] = GroovS3.create_export_csv(Apartment::Tenant.current, result['filename'], data).url.gsub('http:', 'https:')
    end
    result['status'] = true
    CsvExportMailer.send_s3_broken_image_url(result['filename'], tenant).deliver
  end

  def fix_shopify_product_images(tenant, params)
    ProductsService::FixBrokenImages.call(tenant, params)
  end

  def re_associate_all_products(**args)
    ProductsService::ReAssociateAllProducts.call(**args)
  end

  def generate_csv(result, data, filename, products)
    unless result['status']
      data = CSV.generate { |csv| csv << result['messages'] }
      filename = 'error.csv'
    end
    no_product = products.blank?
    object_url = begin
                  GroovS3.create_public_csv(Apartment::Tenant.current, 'product', filename, data).url.gsub('http:', 'https:')
                 rescue StandardError
                   nil
                end
    CsvExportMailer.send_s3_product_object_url(filename, object_url, Apartment::Tenant.current, no_product).deliver
  end

  def assign_single_row(product, single_row)
    single_row[:WeightOz] = product.weight.round == 0 ? '' : product.weight.round.to_s
    single_row[:Category] = product.primary_category
    single_row = single_row.merge(Tag1: '', Tag2: '', Tag3: '', Tag4: '', Tag5: '', CustomsDescription: '', CustomsValue: '', CustomsTariffNo: '', ThumbnailUrl: '', FillSKU: '', Length: '', Width: '', Height: '', UseProductName: '')
    single_row
  end

  def generate_barcode_with_delay(params, data, tenant_name)
    Apartment::Tenant.switch!(tenant_name)
    @result = data[:result]
    @products = list_selected_products(params).includes(:product_kit_skuss, :product_barcodes, :product_skus, :product_kit_activities, :product_inventory_warehousess)
    eager_loaded_obj = Product.generate_eager_loaded_obj(@products)
    @products.each { |product| @result = product.generate_barcode(@result, eager_loaded_obj) }
    GroovRealtime.emit('gen_barcode_with_delay', {}, :tenant) if params['productArray'].count > 20 || params['select_all'] == true
  end

  def generate_numeric_barcode_with_delay(params, data, tenant_name)
    Apartment::Tenant.switch!(tenant_name)
    @result = data[:result]
    @products = list_selected_products(params).includes(:product_kit_skuss, :product_barcodes, :product_skus, :product_kit_activities, :product_inventory_warehousess)

    eager_loaded_obj = Product.generate_eager_loaded_obj(@products)
    @products.each { |product| @result = product.generate_numeric_barcode(@result, eager_loaded_obj) }
    GroovRealtime.emit('gen_barcode_with_delay', {}, :tenant) if params['productArray'].count > 20 || params['select_all'] == true
  end
end
