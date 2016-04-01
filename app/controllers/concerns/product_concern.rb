module ProductConcern
  extend ActiveSupport::Concern
  
  included do
    prepend_before_filter :groovepacker_authorize!
    prepend_before_filter :init_result_object
    before_filter :init_products_service, only: [:import_images]
    include ProductsHelper
    include Groovepacker::Orders::ResponseMessage
  end
  
  private
    def gp_products_module
      Groovepacker::Products::Products.new(result: @result, params_attrs: params, current_user: current_user)
    end

    def init_products_service
      @product_service = ProductService::ProductService.new(result: @result, params: params, current_user: current_user)
    end

    def init_products_import_service(store)
      Groovepacker::Products::Import.new(result: @result, params: params, current_user: current_user, store: store)
    end

    def init_result_object
      @result = { 'status' => true,
        'messages' => [], 
        'total_imported' => 0, 
        'success_imported' => 0, 
        'previous_imported' => 0
      }
    end

    def generate_csv(result)
      products = list_selected_products(params)
      result['filename'] = 'products-'+Time.now.to_s+'.csv'
      CSV.open("#{Rails.root}/public/csv/#{result['filename']}", "w") do |csv|
        ProductsHelper.products_csv(products, csv)
      end
      return result
    end

    def generate_error_csv(result)
      result['filename'] = 'error.csv'
      CSV.open("#{Rails.root}/public/csv/#{result['filename']}", "w") do |csv|
        csv << result['messages']
      end
      return result
    end

    def get_single_product_info(product)
      @product_hash = get_product_attrs(product)
      @product_hash['image'] = product.base_product.primary_image
      @product_hash['store_name'] = product.store.name rescue nil
      get_warehouse_location(product)
      get_product_kit_skus(product)
      return @product_hash
    end

    def get_product_attrs(product)
      return { 'id' => product.id,
              'name' => product.name,
              'status' => product.status,
              'location_primary' => '',
              'location_secondary' => '',
              'location_tertiary' => '',
              'location_name' => 'not_available',
              'type_scan_enabled' => product.type_scan_enabled,
              'click_scan_enabled' => product.click_scan_enabled,
              'qty' => 0,
              'barcode' => '',
              'sku' => '',
              'cat' => '',
              'image' => '',
              'barcode' => product.primary_barcode,
              'sku' => product.primary_sku,
              'cat' => product.primary_category
            }
    end

    def get_warehouse_location(product)
      @product_location = product.primary_warehouse
      
      return if @product_location.nil?
      @product_hash = @product_hash.merge({ 'location_primary' => @product_location.location_primary,
                                            'location_secondary' => @product_location.location_secondary,
                                            'location_tertiary' => @product_location.location_tertiary,
                                            'available_inv' => @product_location.available_inv,
                                            'qty_on_hand' => @product_location.quantity_on_hand
                                        })
      @product_hash['location_name'] = @product_location.inventory_warehouse.name rescue nil
    end

    def get_product_kit_skus(product)
      product_kit_skus = ProductKitSkus.where(:product_id => product.id)
      return if product_kit_skus.blank?
      @product_hash['productkitskus'] = []
      product_kit_skus.each { |kitsku| @product_hash['productkitskus'].push(kitsku.id) }
    end

    def add_new_image
      product = Product.find(params[:id])
      unless product.blank? && params[:product_image].blank?
        return product.add_new_image(params)
        @result['status'] = false
        @result['messages'].push("Adding image failed")
      else
        @result['status'] = false
        @result['messages'].push("Invalid data sent to the server")
      end
    end

    def make_products_list(products)
      @products_result = []
      products.each do |product|
        product_hash = get_single_product_info(product)
        @products_result.push(product_hash)
      end
      return @products_result
    end

    def get_products_count
      count, all = {}, 0
      counts = Product.get_count(params)
      counts.each do |single|
        count[single.status] = single.count
        all += single.count
      end
      count['all'] = all
      count['search'] = 0
      count
    end

    def execute_scan_per_product
      if params[:setting].present? && ['type_scan_enabled', 'click_scan_enabled'].include?(params[:setting])
        products = list_selected_products(params)
        products.each do |product|
          product[params[:setting]] = params[:status]
          next if product.save
          @result['status'] &= false
          @result['messages'].push('There was a problem updating '+product.name)
        end
      else
        @result['status'] = false
        @result['messages'].push('No action specified for updating')
      end
    end
end
