module ProductsHelper

  require 'barby'
  require 'barby/barcode/code_128'
  require 'barby/outputter/png_outputter'

  require 'mws-connect'
  #requires a product is created with appropriate seller sku
  def import_amazon_product_details(store_id, product_sku, product_id)
    Products::AmazonImport.call(store_id, product_sku, product_id)
    # begin
    #   @store = Store.find(store_id)
    #   @amazon_credentials = AmazonCredentials.where(:store_id => store_id)
    #
    #   if @amazon_credentials.length > 0
    #     @credential = @amazon_credentials.first
    #
    #     mws = Mws.connect(
    #       merchant: @credential.merchant_id,
    #       access: ENV['AMAZON_MWS_ACCESS_KEY_ID'],
    #       secret: ENV['AMAZON_MWS_SECRET_ACCESS_KEY']
    #     )
    #     #send request to amazon mws get matching product API
    #     products_xml = mws.products.get_matching_products_for_id(:marketplace_id => @credential.marketplace_id,
    #                                                              :id_type => 'SellerSKU', :id_list => [product_sku])
    #
    #     require 'active_support/core_ext/hash/conversions'
    #     product_hash = Hash.from_xml(products_xml.to_s)
    #
    #     product = Product.find(product_id)
    #
    #     product.name = product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']['Title']
    #
    #     if !product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']['ItemDimensions'].nil? &&
    #       !product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']['ItemDimensions']['Weight'].nil?
    #       product.weight = product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']['ItemDimensions']['Weight'].to_f * 16
    #     end
    #
    #     if !product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']['PackageDimensions'].nil? &&
    #       !product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']['PackageDimensions']['Weight'].nil?
    #       product.shipping_weight = product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']['PackageDimensions']['Weight'].to_f * 16
    #     end
    #
    #     product.store_product_id = product_hash['GetMatchingProductForIdResult']['Products']['Product']['Identifiers']['MarketplaceASIN']['ASIN']
    #
    #     if @credential.import_images
    #       image = ProductImage.new
    #       image.image = product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']['SmallImage']['URL']
    #       product.product_images << image
    #     end
    #
    #     if @credential.import_products
    #       category = ProductCat.new
    #       category.category = product_hash['GetMatchingProductForIdResult']['Products']['Product']['AttributeSets']['ItemAttributes']['ProductGroup']
    #       product.product_cats << category
    #     end
    #
    #     #add inventory warehouse
    #     inv_wh = ProductInventoryWarehouses.new
    #     inv_wh.inventory_warehouse_id = @store.inventory_warehouse_id
    #     product.product_inventory_warehousess << inv_wh
    #
    #     product.save
    #     product.update_product_status
    #   end
    # rescue Exception => e
    #   puts e.inspect
    # end
  end

  def updatelist(product, var, value)
    begin
      if ['name', 'status', 'is_skippable', 'type_scan_enabled', 'click_scan_enabled', 'spl_instructions_4_packer'].include?(var)
        product[var] = value
        product.save
        if var == 'status'
          if value == 'inactive'
            product.update_due_to_inactive_product
          else
            product.update_product_status
          end
        end
      elsif var == 'sku'
        product.primary_sku = value
        return product if product.errors.any?
      elsif var == 'category'
        product.primary_category = value
      elsif var == 'barcode'
        product.primary_barcode = value
        return product if product.errors.any?
      elsif ['location_primary', 'location_secondary', 'location_tertiary', 'location_name', 'qty_on_hand'].include?(var)
        product_location = product.primary_warehouse
        if product_location.nil?
          product_location = ProductInventoryWarehouses.new
          product_location.product_id = product.id
          product_location.inventory_warehouse_id = current_user.inventory_warehouse_id
        end
        if var == 'location_primary'
          product_location.location_primary = value
        elsif var == 'location_secondary'
          product_location.location_secondary = value
        elsif var == 'location_tertiary'
          product_location.location_tertiary = value
        elsif var == 'location_name'
          product_location.name = value
        elsif var == 'qty_on_hand'
          product_location.quantity_on_hand= value
        end
        product_location.save
      end
      product.update_product_status
    rescue Exception => e
      puts e.inspect
    end
  end

  #gets called from orders helper
  def import_ebay_product(itemID, sku, ebay, credential)
    product_id = 0
    if ProductSku.where(:sku => sku).length == 0
      @item = ebay.getItem(:ItemID => itemID).item
      @productdb = Product.new
      @productdb.name = @item.title
      @productdb.store_product_id = @item.itemID
      @productdb.product_type = 'not_used'
      @productdb.status = 'inactive'
      @productdb.store = @store

      weight_lbs = @item.shippingDetails.calculatedShippingRate.weightMajor
      weight_oz = @item.shippingDetails.calculatedShippingRate.weightMinor
      @productdb.weight = weight_lbs * 16 + weight_oz

      #add productdb sku
      @productdbsku = ProductSku.new
      if @item.sKU.nil?
        @productdbsku.sku = "not_available"
      else
        @productdbsku.sku = @item.sKU
      end
      #@item.productListingType.uPC
      @productdbsku.purpose = 'primary'

      #publish the sku to the product record
      @productdb.product_skus << @productdbsku

      if credential.import_images
        if !@item.pictureDetails.nil?
          if !@item.pictureDetails.pictureURL.nil? &&
            @item.pictureDetails.pictureURL.length > 0
            @productimage = ProductImage.new
            @productimage.image = "http://i.ebayimg.com" +
              @item.pictureDetails.pictureURL.first.request_uri()
            @productdb.product_images << @productimage

          end
        end
      end

      if credential.import_products
        if !@item.primaryCategory.nil?
          @product_cat = ProductCat.new
          @product_cat.category = @item.primaryCategory.categoryName
          @productdb.product_cats << @product_cat
        end

        if !@item.secondaryCategory.nil?
          @product_cat = ProductCat.new
          @product_cat.category = @item.secondaryCategory.categoryName
          @productdb.product_cats << @product_cat
        end
      end

      #add inventory warehouse
      inv_wh = ProductInventoryWarehouses.new
      inv_wh.inventory_warehouse_id = @store.inventory_warehouse_id
      @productdb.product_inventory_warehousess << inv_wh

      @productdb.save
      @productdb.set_product_status
      product_id = @productdb.id
    else
      product_id = ProductSku.where(:sku => sku).first.product_id
    end

    product_id
  end

  def generate_barcode(barcode_string)
    barcode = Barby::Code128B.new(barcode_string)
    outputter = Barby::PngOutputter.new(barcode)
    outputter.margin = 0
    blob = outputter.to_png #Raw PNG data
    image_name = Digest::MD5.hexdigest(barcode_string)
    File.open("#{Rails.root}/public/images/#{image_name}.png",
              'w') do |f|
      f.write blob
    end
    image_name
  end

  def list_selected_products(params)
    if params[:select_all] || params[:inverted]
      if !params[:search].nil? && params[:search] != ''
        result = do_search(params)
      else
        result = do_getproducts(params)
      end
    else
      result = params[:productArray]
    end

    result_rows = []
    if params[:inverted] && !params[:productArray].blank?
      not_in = []
      params[:productArray].each do |product|
        not_in.push(product['id'])
      end
      result.each do |single_product|
        unless not_in.include? single_product['id']
          result_rows.push({'id' => single_product['id']})
        end
      end
    else
      result.each do |single_product|
        result_rows.push({'id' => single_product['id']})
      end
    end

    return result_rows
  end

  def do_getproducts(params)
    sort_key = 'updated_at'
    sort_order = 'DESC'
    status_filter = 'active'
    limit = 10
    offset = 0
    query_add = ""
    kit_query = ""
    status_filter_text = ""
    is_kit = 0
    supported_sort_keys = ['updated_at', 'name', 'sku',
                           'status', 'barcode', 'location_primary', 'location_secondary', 'location_tertiary', 'location_name', 'cat', 'available_inv', 'store_type']
    supported_order_keys = ['ASC', 'DESC'] #Caps letters only
    supported_status_filters = ['all', 'active', 'inactive', 'new']
    supported_kit_params = ['0', '1', '-1']

    # Get passed in parameter variables if they are valid.
    limit = params[:limit].to_i if !params[:limit].nil? && params[:limit].to_i > 0

    offset = params[:offset].to_i if !params[:offset].nil? && params[:offset].to_i >= 0

    sort_key = params[:sort] if !params[:sort].nil? &&
      supported_sort_keys.include?(params[:sort].to_s)

    sort_order = params[:order] if !params[:order].nil? &&
      supported_order_keys.include?(params[:order].to_s)

    status_filter = params[:filter] if !params[:filter].nil? &&
      supported_status_filters.include?(params[:filter].to_s)

    is_kit = params[:is_kit].to_i if !params[:is_kit].nil? &&
      supported_kit_params.include?(params[:is_kit].to_s)

    unless is_kit == -1
      kit_query = " WHERE products.is_kit="+is_kit.to_s
    end

    unless params[:select_all] || params[:inverted]
      query_add += " LIMIT "+limit.to_s+" OFFSET "+offset.to_s
    end

    #hack to bypass for now and enable client development
    # sort_key = 'name' if sort_key == 'sku'

    #todo status filters to be implemented

    unless status_filter == 'all'
      if is_kit == '-1'
        status_filter_text = " WHERE "
      else
        status_filter_text = " AND "
      end
      status_filter_text += " products.status='"+status_filter+"'"
    end

    if sort_key == 'sku'
      products = Product.find_by_sql("SELECT products.* FROM products LEFT JOIN product_skus ON ("+
                                       "products.id = product_skus.product_id ) "+kit_query+
                                       status_filter_text+"GROUP BY product_id ORDER BY product_skus.sku "+sort_order+query_add)
    elsif sort_key == 'store_type'
      products = Product.find_by_sql("SELECT products.* FROM products LEFT JOIN stores ON ("+
                                       "products.store_id = stores.id ) "+kit_query+
                                       status_filter_text+" ORDER BY stores.name "+sort_order+query_add)
    elsif sort_key == 'barcode'
      products = Product.find_by_sql("SELECT products.* FROM products LEFT JOIN product_barcodes ON ("+
                                       "products.id = product_barcodes.product_id ) "+kit_query+
                                       status_filter_text+" ORDER BY product_barcodes.barcode "+sort_order+query_add)
    elsif sort_key == 'location_primary'
      products = Product.find_by_sql("SELECT products.* FROM products LEFT JOIN product_inventory_warehouses ON ( "+
                                       "products.id = product_inventory_warehouses.product_id ) "+ kit_query+
                                       status_filter_text+" ORDER BY product_inventory_warehouses.location_primary "+sort_order+query_add)
    elsif sort_key == 'location_secondary'
      products = Product.find_by_sql("SELECT products.* FROM products LEFT JOIN product_inventory_warehouses ON ( "+
                                       "products.id = product_inventory_warehouses.product_id ) "+kit_query+
                                       status_filter_text+" ORDER BY product_inventory_warehouses.location_secondary "+sort_order+query_add)
    elsif sort_key == 'location_tertiary'
      products = Product.find_by_sql("SELECT products.* FROM products LEFT JOIN product_inventory_warehouses ON ( "+
                                       "products.id = product_inventory_warehouses.product_id ) "+kit_query+
                                       status_filter_text+" ORDER BY product_inventory_warehouses.location_tertiary "+sort_order+query_add)
    elsif sort_key == 'location_name'
      products = Product.find_by_sql("SELECT products.* FROM products LEFT JOIN product_inventory_warehouses ON ( "+
                                       "products.id = product_inventory_warehouses.product_id )  LEFT JOIN inventory_warehouses ON("+
                                       "product_inventory_warehouses.inventory_warehouse_id = inventory_warehouses.id ) "+kit_query+
                                       status_filter_text+" ORDER BY inventory_warehouses.name "+sort_order+query_add)
    elsif sort_key == 'available_inv'
      products = Product.find_by_sql("SELECT products.* FROM products LEFT JOIN product_inventory_warehouses ON ( "+
                                       "products.id = product_inventory_warehouses.product_id ) "+kit_query+
                                       status_filter_text+" ORDER BY product_inventory_warehouses.available_inv "+sort_order+query_add)
    elsif sort_key == 'cat'
      products = Product.find_by_sql("SELECT products.* FROM products LEFT JOIN product_cats ON ( "+
                                       "products.id = product_cats.product_id ) "+kit_query+
                                       status_filter_text+" ORDER BY product_cats.category "+sort_order+query_add)
    else
      products = Product.order(sort_key+" "+sort_order)
      unless is_kit == -1
        products = products.where(:is_kit => is_kit.to_s)
      end
      unless status_filter == 'all'
        products = products.where(:status => status_filter)
      end
      unless params[:select_all] || params[:inverted]
        products = products.limit(limit).offset(offset)
      end
    end

    if products.length == 0
      products = Product.where(1)
      unless is_kit == -1
        products = products.where(:is_kit => is_kit.to_s)
      end
      unless status_filter == 'all'
        products = products.where(:status => status_filter)
      end
      unless params[:select_all] || params[:inverted]
        products = products.limit(limit).offset(offset)
      end
    end
    return products
  end

  def do_search(params, results_only = true)
    limit = 10
    offset = 0
    sort_key = 'updated_at'
    sort_order = 'DESC'
    supported_sort_keys = ['updated_at', 'name', 'sku',
                           'status', 'barcode', 'location_primary', 'location_secondary', 'location_tertiary', 'location_name', 'cat', 'qty', 'store_type']
    supported_order_keys = ['ASC', 'DESC'] #Caps letters only

    sort_key = params[:sort] if !params[:sort].nil? &&
      supported_sort_keys.include?(params[:sort].to_s)

    sort_order = params[:order] if !params[:order].nil? &&
      supported_order_keys.include?(params[:order].to_s)

    # Get passed in parameter variables if they are valid.
    limit = params[:limit].to_i if !params[:limit].nil? && params[:limit].to_i > 0

    offset = params[:offset].to_i if !params[:offset].nil? && params[:offset].to_i >= 0
    search = ActiveRecord::Base::sanitize('%'+params[:search]+'%')
    is_kit = 0
    supported_kit_params = ['0', '1', '-1']
    kit_query = ''
    query_add = ''

    is_kit = params[:is_kit].to_i if !params[:is_kit].nil? &&
      supported_kit_params.include?(params[:is_kit])
    unless is_kit == -1
      kit_query = 'AND products.is_kit='+is_kit.to_s+' '
    end
    unless params[:select_all] || params[:inverted]
      query_add = ' LIMIT '+limit.to_s+' OFFSET '+offset.to_s
    end

    base_query = 'SELECT products.id as id, products.name as name, products.type_scan_enabled as type_scan_enabled, products.base_sku as base_sku, products.click_scan_enabled as click_scan_enabled, products.status as status, products.updated_at as updated_at, product_skus.sku as sku, product_barcodes.barcode as barcode, product_cats.category as cat, product_inventory_warehouses.location_primary, product_inventory_warehouses.location_secondary, product_inventory_warehouses.location_tertiary, product_inventory_warehouses.available_inv as qty, inventory_warehouses.name as location_name, stores.name as store_type, products.store_id as store_id
      FROM products
        LEFT JOIN product_skus ON (products.id = product_skus.product_id)
        LEFT JOIN product_barcodes ON (product_barcodes.product_id = products.id)
            LEFT JOIN product_cats ON (products.id = product_cats.product_id)
            LEFT JOIN product_inventory_warehouses ON (product_inventory_warehouses.product_id = products.id)
            LEFT JOIN inventory_warehouses ON (product_inventory_warehouses.inventory_warehouse_id =  inventory_warehouses.id)
            LEFT JOIN stores ON (products.store_id = stores.id)
        WHERE
          (
            products.name like '+search+' OR product_barcodes.barcode like '+search+'
            OR product_skus.sku like '+search+' OR product_cats.category like '+search+'
            OR (
              product_inventory_warehouses.location_primary like '+search+'
              OR product_inventory_warehouses.location_secondary like '+search+'
              OR product_inventory_warehouses.location_tertiary like '+search+'
            )
          )
          '+kit_query+'
        GROUP BY products.id ORDER BY '+sort_key+' '+sort_order

    result_rows = Product.find_by_sql(base_query+query_add)


    if results_only
      result = result_rows
    else
      result = Hash.new
      result['products'] = result_rows
      if params[:select_all] || params[:inverted]
        result['count'] = result_rows.length
      else
        result['count'] = Product.count_by_sql('SELECT count(*) as count from('+base_query+') as tmp')
      end
    end


    return result
  end

  def self.products_csv(products, csv, bulk_actions_id = nil)
    @bulk_action = GrooveBulkActions.find(bulk_actions_id) if bulk_actions_id
    headers = []
    headers.push('ID', 'Name', 'SKU 1', 'Barcode 1', 'BinLocation 1', 'QOH', 'Primary Image', 'Weight', 'Primary Category',
                 'SKU 2', 'SKU 3', 'Barcode 2', 'Barcode 3', 'BinLocation 2', 'BinLocation 3')
    Product.column_names.each do |name|
      unless headers.any? { |s| s.casecmp(name)==0 }
        headers.push(name)
      end
    end
    csv << headers
    products.each do |item|
      data = []
      inventory_wh = ProductInventoryWarehouses.where(:product_id => item.id, :inventory_warehouse_id => InventoryWarehouse.where(:is_default => true).first.id).first
      headers.each do |title|
        if title == 'ID'
          data.push(item.id)
        elsif title == 'Name'
          data.push(item.name)
        elsif title == 'SKU 1'
          data.push(item.primary_sku)
        elsif title == 'Barcode 1'
          data.push(item.primary_barcode)
        elsif title == 'BinLocation 1'
          data.push(inventory_wh.location_primary)
        # elsif title == 'Quantity Avbl'
        #   data.push(inventory_wh.available_inv)
        elsif title == 'QOH'
          data.push(inventory_wh.quantity_on_hand)
        elsif title == 'Primary Image'
          data.push(item.primary_image)
        elsif title == 'Weight'
          data.push(item.weight)
        elsif title == 'Primary Category'
          data.push(item.primary_category)
        elsif title == 'SKU 2'
          if item.product_skus.length >1
            data.push(item.product_skus[1].sku)
          else
            data.push('')
          end
        elsif title == 'SKU 3'
          if item.product_skus.length >2
            data.push(item.product_skus[2].sku)
          else
            data.push('')
          end
        elsif title == 'Barcode 2'
          if item.product_barcodes.length >1
            data.push(item.product_barcodes[1].barcode)
          else
            data.push('')
          end
        elsif title == 'Barcode 3'
          if item.product_barcodes.length >2
            data.push(item.product_barcodes[2].barcode)
          else
            data.push('')
          end
        elsif title == 'BinLocation 2'
          data.push(inventory_wh.location_secondary)
        elsif title == 'BinLocation 3'
          data.push('')
        else
          data.push(item.attributes.values_at(title).first) unless item.attributes.values_at(title).empty?
        end
      end
      if @bulk_action
        @bulk_action.completed += 1
        @bulk_action.save
      end
      csv << data
    end
    csv
  end

  def make_product_intangible(product)
    scan_pack_settings = ScanPackSetting.all.first
    if scan_pack_settings.intangible_setting_enabled
      unless scan_pack_settings.intangible_string.nil? || (scan_pack_settings.intangible_string.strip.equal? (''))
        intangible_strings = scan_pack_settings.intangible_string.strip.split(",")
        intangible_strings.each do |string|
          if (product.name.include? (string)) || (product.primary_sku.include? (string))
            product.is_intangible = true
            product.save
            break
          end
        end
      end
    end
  end

  def get_weight_format(weight_format)
    unless weight_format.nil?
      return weight_format
    else
      return GeneralSetting.get_product_weight_format
    end
  end
end
