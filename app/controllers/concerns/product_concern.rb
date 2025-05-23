# frozen_string_literal: true

module ProductConcern
  extend ActiveSupport::Concern

  included do
    prepend_before_action :groovepacker_authorize!, except: %i[generate_barcode_slip bulk_barcode_pdf]
    prepend_before_action :init_result_object
    before_action :check_permissions, only: %i[generate_barcode scan_per_product add_product_to_kit remove_products_from_kit update_product_list add_image update_intangibleness change_product_status delete_product duplicate_product]
    before_action :find_kit_product, only: %i[add_product_to_kit remove_products_from_kit]
    before_action :init_products_service, only: [:import_images]
    include ProductsHelper
    include Groovepacker::Orders::ResponseMessage
  end

  def check_permissions
    begin
      return if params['var'] == 'barcode' && params['action'] == 'update_product_list'
    rescue StandardError
      nil
    end
    unless current_user.can?('add_edit_products')
      @result['status'] = false
      @result['messages'] = add_error_message
      render(json: @result) && return
    end
  end

  private

  def gp_products_module
    Groovepacker::Products::Products.new(result: @result, params_attrs: params, current_user: current_user, session: session)
  end

  def init_products_service
    @product_service = ProductService::ProductService.new(result: @result, params: params, current_user: current_user)
  end

  def init_products_import_service(store)
    Groovepacker::Products::Import.new(result: @result, params: params, current_user: current_user, store: store)
  end

  def product_aliasing
    Groovepacker::Products::Aliasing.new(result: @result, params_attrs: params, current_user: current_user)
  end

  def find_kit_product
    @kit = Product.find_by_id(params[:id])
  end

  def init_result_object
    @result = { 'status' => true,
                'messages' => [],
                'total_imported' => 0,
                'success_imported' => 0,
                'previous_imported' => 0,
                'error_messages' => [],
                'success_messages' => [],
                'notice_messages' => [] }
  end

  def generate_csv(result)
    result['filename'] = 'products-' + Time.current.to_s + '.csv'
    tenant = Apartment::Tenant.current
    product = Groovepacker::Products::Products.new
    product.delay(priority: 95).create_product_export(params, result, tenant)
    result
  end

  def generate_error_csv(result)
    result['filename'] = 'error.csv'
    CSV.open("#{Rails.root}/public/csv/#{result['filename']}", 'w') do |csv|
      csv << result['messages']
    end
    # public_url = GroovS3.get_csv_export_exception(result['filename'])
    # result = {url: public_url, filename: result['filename']}
    result
  end

  def get_single_product_info(product)
    @product_hash = get_product_attrs(product)
    @product_hash['image'] = product.base_product.primary_image
    @product_hash['store_name'] = begin
                                      product.store.name
                                  rescue StandardError
                                    nil
                                    end
    get_warehouse_location(product)
    get_product_kit_skus(product)
    @product_hash
  end

  def get_product_attrs(product)
    { 'id' => product.id,
      'name' => product.name,
      'status' => product.status,
      'location_primary' => '',
      'location_secondary' => '',
      'location_tertiary' => '',
      'location_name' => 'not_available',
      'type_scan_enabled' => product.type_scan_enabled,
      'click_scan_enabled' => product.click_scan_enabled,
      'qty' => 0,
      'image' => '',
      'barcode' => product.primary_barcode,
      'sku' => product.primary_sku,
      'cat' => product.primary_category,
      'custom_product_1' => product.custom_product_1,
      'custom_product_2' => product.custom_product_2,
      'custom_product_3' => product.custom_product_3 }
  end

  def get_warehouse_location(product)
    @product_location = product.primary_warehouse

    return if @product_location.nil?

    @product_hash = @product_hash.merge('location_primary' => @product_location.location_primary,
                                        'location_secondary' => @product_location.location_secondary,
                                        'location_tertiary' => @product_location.location_tertiary,
                                        'available_inv' => @product_location.available_inv,
                                        'qty_on_hand' => @product_location.quantity_on_hand)
    @product_hash['location_name'] = begin
                                         @product_location.inventory_warehouse.name
                                     rescue StandardError
                                       nil
                                       end
  end

  def get_product_kit_skus(product)
    product_kit_skus = product.product_kit_skuss # ProductKitSkus.where(:product_id => product.id)
    return if product_kit_skus.blank?

    @product_hash['productkitskus'] = []
    product_kit_skus.each { |kitsku| @product_hash['productkitskus'].push(kitsku.id) }
  end

  def add_new_image(product)
    if product.blank? && params[:product_image].blank?
      @result['status'] = false
      @result['messages'].push('Invalid data sent to the server')
    else
      return product.add_new_image(params)
      @result['status'] = false
      @result['messages'].push('Adding image failed')
    end
  end

  def make_products_list(products)
    @products_result = []
    products.each do |product|
      product_hash = get_single_product_info(product)
      @products_result.push(product_hash)
    end
    @products_result
  end

  def get_products_count
    count = {}
    all = 0
    counts = Product.get_count(params)
    counts.each do |single|
      count[single.status] = single.count
      all += single.count
    end
    count['all'] = all
    count['search'] = 0
    count
  end

  def get_report_products_count
    count = {}
    all = 0
    product_report = ProductInventoryReport.where(id: params[:report_id]).first
    products = product_report.products
    if product_report
      count['all'] = products.count
      count.merge!(products.group(:status).count)
    end
    params[:limit] = Product.count
    count['search'] = params[:search].present? ? do_get_report_products(params).count : 0
    count
  end

  def execute_scan_per_product
    if params[:setting].present? && %w[type_scan_enabled click_scan_enabled].include?(params[:setting])
      products = list_selected_products(params)
      products.each do |product|
        update_product_status(product)
      end
    else
      @result['status'] = false
      @result['messages'].push('No action specified for updating')
    end
  end

  def update_product_status(product)
    product[params[:setting]] = params[:status]
    return if product.save

    @result['status'] &= false
    @result['messages'].push('There was a problem updating ' + product.name)
  end

  def add_error_message
    error_messages = {
      'generate_barcode' => 'to generate barcodes',
      'scan_per_product' => 'to edit this product',
      'add_product_to_kit' => 'to add a product to a kit',
      'remove_products_from_kit' => 'to remove products from kits',
      'update_product_list' => 'to edit product list',
      'add_image' => 'to add image to a product',
      'update_intangibleness' => 'to edit product status',
      'change_product_status' => 'to edit product status',
      'delete_product' => 'to delete a product',
      'duplicate_product' => ' to duplicate a product'
    }

    "You do not have enough permissions #{error_messages[params['action']]}"
  end

  def check_if_not_a_kit
    unless @kit.is_kit
      @result['messages'].push("Product with id=#{@kit.id} is not a kit")
      @result['status'] &= false
    end
    @result['status']
  end
end
