module ProductMethodsHelper
  def add_product_activity(product_activity_message, username='', activity_type ='regular')
    @activity = ProductActivity.new
    @activity.product_id = self.id
    @activity.action = product_activity_message
    @activity.username = username
    @activity.activitytime = current_time_from_proper_timezone
    @activity.activity_type = activity_type
    @activity.user_id = User.find_by_username(username).try(:id)
    @activity.user_id = User.find_by_name(username).try(:id) if @activity.user_id.nil?
    @activity.save
  end

  def gen_barcode_from_sku_if_intangible
    return unless is_intangible
    sku_for_barcode = product_skus.find_by_purpose('primary')
    sku_for_barcode = product_skus.first unless sku_for_barcode
    # method will not generate barcode if already exists
    sku_for_barcode.gen_barcode_from_sku_if_intangible_product if sku_for_barcode.present?
  end

  def add_new_image(params)
    image = product_images.build
    # image_directory = "public/images"
    current_tenant = Apartment::Tenant.current
    file_name = create_image_from_req(params, current_tenant)

    #path = File.join(image_directory, file_name )
    #File.open(path, "wb") { |f| f.write(params[:product_image].read) }
    image.image = ENV['S3_BASE_URL']+'/'+current_tenant+'/image/'+file_name
    image.caption = params[:caption]  unless params[:caption].blank?
    image.save
  end

  def create_image_from_req(params, current_tenant)
    unless params[:base_64_img_upload]
      file_name = Time.now.strftime('%d_%b_%Y_%I__%M_%p')+self.id.to_s+params[:product_image].original_filename
      GroovS3.create_image(current_tenant, file_name, params[:product_image].read, params[:product_image].content_type)
      # return file_name
    else
      image_content = Base64.decode64(params[:product_image][:image].to_s)
      content_type = params[:product_image][:content_type]
      file_name = Time.now.strftime('%d_%b_%Y_%I__%M_%p')+self.id.to_s+params[:product_image][:original_filename]
      GroovS3.create_image(current_tenant, file_name, image_content, content_type)
      # return file_name
    end
    file_name
  end

  def generate_barcode(result, eager_loaded_obj = {})
    if product_barcodes.blank?
      sku = product_skus.first
      unless sku.nil?
        barcode = product_barcodes.new
        barcode.barcode = sku.sku
        unless barcode.save
          result['status'] &= false
          result['messages'].push(barcode.errors.full_messages)
        end
      end
    end
    update_product_status(nil, eager_loaded_obj)
    result
  end

  def create_or_update_productkitsku(kit_product, products=[])
    actual_product =
      products.find do |_product|
        _product.product_id == id &&
        _product.option_product_id == kit_product['option_product_id']
      end ||
      ProductKitSkus.find_by_option_product_id_and_product_id(kit_product['option_product_id'], id)

    return unless actual_product
    actual_product.qty = kit_product['qty']
    actual_product.packing_order = kit_product['packing_order']
    actual_product.save
  end

  def create_or_update_product_sku_or_barcode(item, order, status = nil, db_item=nil,current_user, item_type)
    return true if (item_type == 'barcode' && db_item && db_item.barcode == item[item_type.downcase])
    product_item = status == 'new' ? (item_type == 'barcode' ? ProductBarcode.new : ProductSku.new) : db_item
    product_item.product.add_product_activity( "The #{item_type} of this item was changed from #{product_item.send(item_type.downcase.to_sym)} to #{item[item_type.downcase]} ",current_user.username) if (status != 'new' && item[item_type.downcase] != product_item.send(item_type.downcase.to_sym))
    product_item.send(item_type.downcase + '=', item[item_type.downcase])
    product_item.purpose = item['purpose'] if item_type == 'SKU'
    product_item.product_id = id unless product_item.persisted?
    product_item.order = order
    product_item.product.add_product_activity( "The #{item_type} #{product_item.send(item_type.downcase.to_sym)} was added to this item",current_user.username) if status == 'new'
    item[:permit_same_barcode] ? product_item.save(validate: false) : product_item.save
  end

  def create_or_update_productimage(image, order, images=[])
    product_image = images.find{|_img| _img.id == image["id"]} || ProductImage.new
    product_image.image = image['image']
    product_image.caption = image['caption']
    product_image.product_id = id unless product_image.persisted?
    product_image.order = order
    product_image.save
  end

  def create_or_update_productcat(category, categories=[])
    product_cat = categories.find{|cat| cat.id == category['id']} || ProductCat.new
    product_cat.category = category['category']
    product_cat.product_id = id unless product_cat.persisted?
    product_cat.save
  end

  def contains_intangible_string
    scan_pack_settings = ScanPackSetting.all.first
    if scan_pack_settings.intangible_setting_enabled
      unless scan_pack_settings.intangible_string.nil? || (scan_pack_settings.intangible_string.strip.equal? '')
        intangible_string = scan_pack_settings.intangible_string
        intangible_strings = intangible_string.split(',')
        intangible_strings.each do |string|
          return true if (name.include? string) || sku_contains_string(string)
        end
      end
    end
    false
  end

  def sku_contains_string(string)
    product_skus = self.product_skus
    product_skus.each do |product_sku|
      return true if product_sku.sku.include? string
    end
    false
  end

  def primary_warehouse
    default_inv_id = InventoryWarehouse.where(is_default: true).first.try :id
    product_inventory_warehousess.find do |p_inv|
      p_inv.inventory_warehouse_id.eql?(default_inv_id)
    end
  end

  def unacknowledged_kit_activities
    product_kit_activities
      .where('activity_type in (:types)', types: 'deleted_item')
      .where(acknowledged: false)
  end

  def is_active
    status == 'active' ? 'TRUE' : 'FALSE'
  end

  def get_show_weight_format
    weight_format.nil? ? GeneralSetting.get_product_weight_format : weight_format
  end

  def get_product_weight(weight)
    weight_format = get_show_weight_format
    case weight_format
    when 'lb'
      @lbs = 16 * weight.to_f
    when 'oz'
      @oz = weight.to_f
    when 'kg'
      @kgs = 1000 * weight.to_f
      @kgs * 0.035274
    else
      @gms = weight.to_f
      @gms * 0.035274
    end
  end

  def get_inventory_warehouse_info(inventory_warehouse_id)
    product_inventory_warehouses =
      ProductInventoryWarehouses.where(inventory_warehouse_id: inventory_warehouse_id)
                                .where(product_id: id)
    product_inventory_warehouses.first
  end

  # provides primary image if exists
  def primary_image
    primary_image_obj.try :image
  end

  def primary_image_obj
    # Faster incase of eger loaded data in times
    # Takes 9.5e-05 seconds
    product_images.sort { |a, b| a.order.to_i <=> b.order.to_i }.first
  end

  def primary_image=(value)
    primary = primary_image_obj
    primary = product_images.new if primary.nil?
    primary.order = 0
    primary.image = value
    primary.save
  end

  # provides primary barcode if exists
  def primary_barcode
    primary_barcode_obj.try :barcode
  end

  def primary_barcode_qty
    primary_barcode_obj.try(:packing_count)
  end

  def primary_barcode_obj
    # Faster incase of eger loaded data in times
    # Takes 9.5e-05 seconds
    product_barcodes.sort { |a, b| a.order.to_i <=> b.order.to_i }.first
  end

  def check_barcode_add_update(params, result)
    db_barcode = ProductBarcode.find_by_barcode(params[:value])
    if db_barcode && (product_barcodes.pluck(:barcode).exclude? params[:value]) && !params[:permit_same_barcode]
      result['current_product_data'] = { id: id, name: name, sku: product_skus.map(&:sku).join(', '), barcode: product_barcodes.map(&:barcode).join(', ') }
      result['alias_product_data'] = { id: db_barcode.product.id, name: db_barcode.product.name, sku: db_barcode.product.product_skus.map(&:sku).join(', '), barcode: db_barcode.product.product_barcodes.map(&:barcode).join(', ') }
      result['after_alias_product_data'] = result['alias_product_data'].dup
      result['after_alias_product_data'][:sku] = (result['alias_product_data'][:sku].split(', ') << product_skus.map(&:sku)).flatten.compact.join(', ')
      result['shared_bacode_products'] = ProductBarcode.get_shared_barcode_products(params[:value])
      result['matching_barcode'] = params[:value]
      result['show_alias_popup'] = true
      result['status'] = false
    elsif (product_barcodes.pluck(:barcode).include? params[:value]) && Product.find(id).primary_barcode != params[:value]
      result['status'] = false
      result['error_msg'] = "The Barcode \"#{params[:value]}\" is already associated with: <br> #{db_barcode.product.name} <br> #{primary_sku}"
    elsif (product_barcodes.pluck(:barcode).include? params[:value]) && Product.find(id).primary_barcode == params[:value]
      result['status'] = true
    elsif (params[:permit_same_barcode] && (product_barcodes.pluck(:barcode).exclude? params[:value])) || db_barcode.blank?
      response = updatelist(self, params[:var], params[:value], params[:current_user], params[:permit_same_barcode])
      errors = response.errors.full_messages rescue nil
      result = result.merge('status' => false, 'error_msg' => errors) if errors
    end
    result
  end
end
