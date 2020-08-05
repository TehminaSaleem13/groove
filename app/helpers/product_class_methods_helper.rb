module ProductClassMethodsHelper
  # def to_csv(folder, options = {})
  #   require 'csv'
  #   response = {}
  #   tables = {
  #     products: self, product_barcodes: ProductBarcode, product_images: ProductImage,
  #     product_skus: ProductSku, product_cats: ProductCat, product_kit_skus: ProductKitSkus,
  #     product_inventory_warehouses: ProductInventoryWarehouses
  #   }
  #   tables.each do |ident, model|
  #     CSV.open("#{folder}/#{ident}.csv", 'w', options) do |csv|
  #       headers = []
  #       if ident == :products
  #         ProductsHelper.products_csv(model.all, csv)
  #       else
  #         headers = model.column_names.dup
  #         csv << headers
  #         model.all.each do |item|
  #           data = []
  #           data = item.attributes.values_at(*model.column_names).dup
  #           csv << data
  #         end
  #       end
  #       response[ident] = "#{folder}/#{ident}.csv"
  #     end
  #   end
  #   response
  # end

  def generate_eager_loaded_obj(products)
    product_ids = products.pluck(:id)

    #delete all caches
    Rails.cache.delete_matched("*for_tenant_#{Apartment::Tenant.current}") rescue nil

    # To reduce individual product query fire on order items

      option_products_if_kit_one = Product.where(
          id: products.where(is_kit: 1).map{|p| p.product_kit_skuss.collect(&:option_product_id)}.flatten
        )
      multi_product_order_items =
        OrderItem.where(product_id: product_ids, scanned_status: 'notscanned')
        .includes(
          :order_item_kit_products,
          :product,
          order: [order_items: :product]
        )

      kit_skus_if_kit_zero =
        ProductKitSkus.where(option_product_id: products.where(is_kit: 0).pluck(:id))
        .includes(product: :product_kit_skuss)

      multi_base_sku_products = Product.where(base_sku: products.map(&:primary_sku))

      eager_loaded_obj = {
        multi_product_order_items: multi_product_order_items,
        kit_skus_if_kit_zero: kit_skus_if_kit_zero,
        option_products_if_kit_one: option_products_if_kit_one,
        multi_base_sku_products: multi_base_sku_products
      }

    eager_loaded_obj
  end

  def emit_message_for_access_token
    result = {"message" => "The Shopfiy token appears to be invalid. Please disconnect and re-authorize your Shopify store. If you see this issue occur regularly please contact GroovePacker support."}
    GroovRealtime::emit('access_token_message', result, :tenant)
  end

  def update_action_intangibleness(params)
    action_intangible = Groovepacker::Products::ActionIntangible.new
    scan_pack_setting = ScanPackSetting.all.first
    intangible_setting_enabled = scan_pack_setting.intangible_setting_enabled
    intangible_string = scan_pack_setting.intangible_string
    action_intangible.delay(run_at: 1.seconds.from_now, queue: "update_intangibleness").update_intangibleness(Apartment::Tenant.current, params, intangible_setting_enabled, intangible_string)
    # action_intangible.update_intangibleness(Apartment::Tenant.current, params, intangible_setting_enabled, intangible_string)
  end

  def create_new_product(result, current_user)
    if current_user.can?('add_edit_products')
      product = Product.new
      product.name = 'New Product'
      product.store_id = Store.where(store_type: 'system').first.id
      product.save
      product.store_product_id = product.id
      product.save
      result['product'] = product
    else
      result['status'] = false
      result['messages'].push('You do not have enough permissions to create a product')
    end
    result
  end

  def get_count(params)
    is_kit = 0
    supported_kit_params = ['0', '1', '-1']
    is_kit = params[:is_kit] if supported_kit_params.include?(params[:is_kit])
    conditions = { status: %w(active inactive new) }
    conditions[:is_kit] = is_kit.to_s unless is_kit == '-1'
    counts = Product.select('status,count(*) as count').where(conditions).group(:status)
  end

  def update_product_list(params, result)
    product = Product.find_by_id(params[:id])
    return result.merge('status' => false, 'error_msg' => 'Cannot find Product') if product.nil?
    if params[:var] == 'barcode'
      result = product.check_barcode_add_update(params, result)
    else
      response = product.updatelist(product, params[:var], params[:value], params[:current_user])
      errors = response.errors.full_messages rescue nil
      result = result.merge('status' => false, 'error_msg' => errors) if errors
    end
    result
  end
end
