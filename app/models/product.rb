class Product < ActiveRecord::Base
  include ProductsHelper
  belongs_to :store

  attr_accessible :name,
                  :product_type,
                  :store_product_id,
                  :status,
                  :spl_instructions_4_packer,
                  :spl_instructions_4_confirmation,
                  :is_skippable,
                  :packing_placement,
                  :pack_time_adj,
                  :is_kit,
                  :kit_parsing,
                  :disable_conf_req,
                  :store,
                  :weight,
                  :add_to_any_order,
                  :is_intangible,
                  :base_sku,
                  :product_receiving_instructions,
                  :second_record_serial,
                  :record_serial,
                  :click_scan_enabled,
                  :is_skippable,
                  :add_to_any_order,
                  :type_scan_enabled

  has_many :product_skus, dependent: :destroy
  has_many :product_cats, dependent: :destroy
  has_many :product_barcodes, dependent: :destroy
  has_many :product_images, dependent: :destroy
  has_many :product_kit_skuss, dependent: :destroy
  has_many :product_inventory_warehousess, dependent: :destroy
  has_many :order_serial
  has_many :order_items
  has_many :product_kit_activities, dependent: :destroy
  has_many :product_lots
  has_and_belongs_to_many :product_inventory_reports, join_table: :products_product_inventory_reports
  has_one :sync_option
  has_many :product_activities, :dependent => :destroy

  after_save :check_inventory_warehouses
  after_save :gen_barcode_from_sku_if_intangible

  cached_methods :product_skus, :product_images,
                 :product_barcodes, :product_kit_skuss,
                 :primary_sku
  after_save :delete_cache
  after_save :check_and_update_status_updated_column

  SINGLE_KIT_PARSING = 'single'.freeze
  DEPENDS_KIT_PARSING = 'depends'.freeze
  INDIVIDUAL_KIT_PARSING = 'individual'.freeze

  SINGLE_SCAN_STATUSES = [SINGLE_KIT_PARSING, DEPENDS_KIT_PARSING].freeze
  INDIVIDUAL_SCAN_STATUSES = [INDIVIDUAL_KIT_PARSING].freeze

  def self.to_csv(folder, options = {})
    require 'csv'
    response = {}
    tables = {
      products: self,
      product_barcodes: ProductBarcode,
      product_images: ProductImage,
      product_skus: ProductSku,
      product_cats: ProductCat,
      product_kit_skus: ProductKitSkus,
      product_inventory_warehouses: ProductInventoryWarehouses
    }
    tables.each do |ident, model|
      CSV.open("#{folder}/#{ident}.csv", 'w', options) do |csv|
        headers = []
        if ident == :products
          ProductsHelper.products_csv(model.all, csv)
        else
          headers = model.column_names.dup

          csv << headers

          model.all.each do |item|
            data = []
            data = item.attributes.values_at(*model.column_names).dup

            csv << data
          end
        end
        response[ident] = "#{folder}/#{ident}.csv"
      end
    end
    response
  end

  def check_inventory_warehouses
    if Product.find(self.id).product_inventory_warehousess.empty?
      inventory = ProductInventoryWarehouses.new
      inventory.product_id = id
      inventory.inventory_warehouse = InventoryWarehouse.where(is_default: true).first
      inventory.save
    end

    true
  end

  def self.generate_eager_loaded_obj(products)
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

  def update_product_status(force_from_inactive_state = false, eager_loaded_obj = {})
    # original_status = self.status
    bulkaction = Groovepacker::Inventory::BulkActions.new
    general_setting = GeneralSetting.setting

    @order_items = if eager_loaded_obj[:multi_product_order_items]
      eager_loaded_obj[:multi_product_order_items].select{ |oi| oi.product_id == id }
    else
      OrderItem.where(
        product_id: id, scanned_status: 'notscanned'
      )
      .includes(
        :order_item_kit_products,
        :product,
        order: [order_items: :product]
      )
    end

    if status != 'inactive' || force_from_inactive_state
      result = true

      result &= false if name.nil? || name == ''

      result &= false if product_skus.empty?

      result &= false if product_barcodes.empty?

      unless base_sku.nil?
        if base_product.status == 'inactive' || base_product.status == 'new'
          result &= false
        end
      end

      # if kit it should contain kit products as well
      if is_kit == 1
        result &= false if product_kit_skuss.empty?
        option_products =
          if eager_loaded_obj[:option_products_if_kit_one]
            eager_loaded_obj[:option_products_if_kit_one]
              .select{ |p| (p.product_kit_skuss - product_kit_skuss).empty? }
          else
            Product.where(
              id: product_kit_skuss.collect(&:option_product_id)
            )
          end

        option_products.each do |option_product|
          if !option_product.nil? &&
             option_product.status != 'active'
            result &= false
          end
        end
        result &= false unless unacknowledged_kit_activities.empty?
      end

      if result
        self.status = 'active'
        save
      else
        self.status = 'new'
        save
      end

      # unless self.status == original_status
      # for non kit products, update all kits product statuses where the
      # current product is an item of the kit
      if is_kit == 0
        @kit_products =
          if eager_loaded_obj[:kit_skus_if_kit_zero]
            eager_loaded_obj[:kit_skus_if_kit_zero]
              .select{ |pkss| pkss.option_product_id == id }
          else
            ProductKitSkus.where(option_product_id: id).includes(product: :product_kit_skuss)
          end
        
        # To reduce individual product query fire on order items
        multi_product_order_items =
          OrderItem.where(product_id: @kit_products.map{|kp| kp.product.id}, scanned_status: 'notscanned')
          .includes(order: [order_items: [:product, :order_item_kit_products]])

        #result_kit = true
        @kit_products.each do |kit_product|
          if kit_product.product.status != 'inactive'
            kit_product.product.update_product_status(nil, {
              multi_product_order_items: multi_product_order_items
            })
          end
        end
      end

      if result && base_sku.nil?
        products =
          if eager_loaded_obj[:multi_base_sku_products]
            eager_loaded_obj[:multi_base_sku_products]
              .select{ |p| p.base_sku == primary_sku }
          else
            Product.where(base_sku: primary_sku)
          end

        # To reduce individual product query fire on order items
        multi_product_order_items =
          OrderItem.where(product_id: products.map(&:id), scanned_status: 'notscanned')
          .includes(order: [order_items: [:product, :order_item_kit_products]])

        products.each{|p| p.update_product_status(nil, {
          multi_product_order_items: multi_product_order_items
        })} unless products.empty?
      end
    end
    # update order items status from onhold to awaiting
    # if @order_items.count > 50
    #   process_order_item
    # else
    #   @order_items.each do |item|
        # item.order.update_order_status unless item.order.nil? ||
        #                                      !%w(awaiting onhold)
        #                                      .include?(item.order.status)
    #     bulkaction.process(item) if general_setting.inventory_tracking?
    #     item.delete_cache_for_associated_obj
    #   end
    # end
    result
  end

  def process_order_item
    obj = self
    obj.update_column(:status_updated, true)
    updated_products = Product.where(status_updated: true)
    orders = Order.includes(:order_items).where("order_items.product_id IN (?)", updated_products.map(&:id))
    return if orders.length<1
    action = GrooveBulkActions.where(identifier: "order", activity: "status_update", status: "pending").first
    if action.blank?
      action = GrooveBulkActions.new(identifier: "order", activity: "status_update", status: "pending")
    end
    action.total = orders.count
    action.save
  end

  def check_and_update_status_updated_column
    if self.changes["status"].present?
      process_order_item
    end
  end

  def update_due_to_inactive_product
    return unless status == 'inactive'

    kit_products = ProductKitSkus.where(
      option_product_id: id
    ).includes(:product)

    order_items = OrderItem.where(
      product_id: kit_products.map(&:product_id).push(id),
      scanned_status: 'notscanned'
    ).includes(order: [order_items: :product])

    kit_products.each do |kit_product|
      next unless kit_product.product.status != 'inactive'
      kit_product.product.status = 'new'
      kit_product.product.save
      tmp_order_items = order_items.select { |oi| oi.product_id = kit_product.product_id }
      tmp_order_items.each do |item|
        item.order.update_order_status unless item.order.nil?
        item.delete_cache_for_associated_obj
      end
    end

    order_items = order_items.select { |oi| oi.product_id = id }
    order_items.each do |item|
      item.order.update_order_status unless item.order.nil?
      item.delete_cache_for_associated_obj
    end
  end

  def set_product_status
    result = true

    @skus = ProductSku.where(product_id: id)
    result &= false if @skus.empty?

    @barcodes = ProductBarcode.where(product_id: id)
    result &= false if @barcodes.empty?

    result &= false unless unacknowledged_kit_activities.empty?

    self.status = if result
                    'active'
                  else
                    'new'
                  end
    save
  end

  def should_scan_as_single_product?
    !should_scan_as_individual_items?
  end

  def should_scan_as_individual_items?
    is_kit == 1
  end

  def get_total_avail_loc
    total_avail_loc = 0
    product_inventory_warehousess.each do |inv_wh|
      total_avail_loc += inv_wh.available_inv
    end
    total_avail_loc
  end

  def get_total_sold_qty
    total_sold_qty = 0
    product_inventory_warehousess.all.each do |inv_wh|
      total_sold_qty += inv_wh.sold_inv
    end
    total_sold_qty
  end

  def get_weight
    format = get_show_weight_format
    weight_gms = weight * 28.349523125
    if format == 'lb'
      return (weight / 16).round(2)
    elsif format == 'oz'
      return weight
    elsif format == 'kg'
      return (weight_gms / 1000).round(3)
    else
      return weight_gms.round
    end
  end

  def get_shipping_weight
    format = get_show_weight_format
    weight_gms = shipping_weight * 28.349523125
    if format == 'lb'
      return (shipping_weight / 16).round(2)
    elsif format == 'oz'
      return shipping_weight
    elsif format == 'kg'
      return (weight_gms / 1000).round(3)
    else
      return weight_gms.round
    end
  end

  def get_inventory_warehouse_info(inventory_warehouse_id)
    product_inventory_warehouses =
      ProductInventoryWarehouses.where(inventory_warehouse_id: inventory_warehouse_id)
                                .where(product_id: id)
    product_inventory_warehouses.first
  end

  # provides primary sku if exists
  def primary_sku
    # self.product_skus.order('product_skus.order ASC').first.try :sku
    primary_sku_obj.try :sku
  end

  def primary_sku_obj
    # Faster incase of eger loaded data in times
    # Takes 9.5e-05 seconds
    product_skus.sort { |a, b| a.order.to_i <=> b.order.to_i }.first
  end

  def primary_sku=(value)
    primary = primary_sku_obj
    primary = product_skus.new if primary.nil?
    primary.order = 0
    primary.sku = value
    errors.add(:base, "Sku #{primary.sku} already exists") unless primary.save
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

  def base_product
    if base_sku.present?
      base_product_sku = ProductSku
                         .where(sku: base_sku)
                         .includes(
                           product: [
                             :product_inventory_warehousess,
                             :product_skus, :product_cats, :product_barcodes,
                             :product_images
                           ]
                         ).first
      return base_product_sku.try :product
    else
      return self
    end
  end

  def primary_barcode=(value)
    primary = primary_barcode_obj
    primary = product_barcodes.new if primary.nil?
    primary.order = 0
    primary.barcode = value
    unless primary.save
      errors.add(:base, "Barcode #{primary.barcode} already exists")
    end
  end

  # provides primary category if exists
  def primary_category
    product_cats.first.try :category
  end

  def primary_category=(value)
    primary = product_cats.first
    primary = product_cats.new if primary.nil?
    primary.category = value
    primary.save
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

  def get_product_weight(weight)
    if weight_format.nil?
      if GeneralSetting.get_product_weight_format == 'lb'
        @lbs = 16 * weight.to_f
      elsif GeneralSetting.get_product_weight_format == 'oz'
        @oz = weight.to_f
      elsif GeneralSetting.get_product_weight_format == 'kg'
        @kgs = 1000 * weight.to_f
        @kgs * 0.035274
      else
        @gms = weight.to_f
        @gms * 0.035274
      end
    else
      if weight_format == 'lb'
        @lbs = 16 * weight.to_f
      elsif weight_format == 'oz'
        @oz = weight.to_f
      elsif weight_format == 'kg'
        @kgs = 1000 * weight.to_f
        @kgs * 0.035274
      else
        @gms = weight.to_f
        @gms * 0.035274
      end
    end
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

  def get_show_weight_format
    if weight_format.nil?
      return GeneralSetting.get_product_weight_format
    else
      return weight_format
    end
  end

  def create_or_update_productcat(category, categories=[])
    product_cat = categories.find{|cat| cat.id == category['id']} || ProductCat.new
    product_cat.category = category['category']
    product_cat.product_id = id unless product_cat.persisted?
    response = product_cat.save ? true : false
    response
  end

  def create_or_update_productimage(image, order, images=[])
    product_image = images.find{|_img| _img.id == image["id"]} || ProductImage.new
    product_image.image = image['image']
    product_image.caption = image['caption']
    product_image.product_id = id unless product_image.persisted?
    product_image.order = order
    response = product_image.save ? true : false
    response
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

  def create_or_update_productsku(sku, order, status = nil, db_sku=nil,current_user)
    product_sku = status == 'new' ? ProductSku.new : db_sku
    product_sku.product.add_product_activity( "The SKU of this item was changed from #{product_sku.sku} to #{sku['sku']} ",current_user.username) if (status != 'new' && sku['sku'] != product_sku.sku)
    product_sku.sku = sku['sku']
    product_sku.purpose = sku['purpose']
    product_sku.product_id = id unless product_sku.persisted?
    product_sku.order = order
    product_sku.product.add_product_activity( "The SKU #{product_sku.sku} was added to this item",current_user.username) if status == 'new'
    response = product_sku.save ? true : false
    response
  end

  def create_or_update_productbarcode(barcode, order, status = nil, db_barcode=nil, current_user)
    product_barcode = status == 'new' ? ProductBarcode.new : db_barcode
    product_barcode.product.add_product_activity( "The barcode of this item was changed from #{product_barcode.barcode} to #{barcode['barcode']} ",current_user.username) if (status != 'new' && barcode['barcode'] != product_barcode.barcode)
    product_barcode.barcode = barcode['barcode']
    product_barcode.product_id = id unless product_barcode.persisted?
    product_barcode.order = order
    product_barcode.product.add_product_activity( "The barcode #{product_barcode.barcode} was added to this item",current_user.username) if status == 'new'
    response = product_barcode.save ? true : false
    response
  end

  def self.update_action_intangibleness(params)
    action_intangible = Groovepacker::Products::ActionIntangible.new
    scan_pack_setting = ScanPackSetting.all.first
    intangible_setting_enabled = scan_pack_setting.intangible_setting_enabled
    intangible_string = scan_pack_setting.intangible_string
    action_intangible.delay(run_at: 1.seconds.from_now).update_intangibleness(Apartment::Tenant.current, params, intangible_setting_enabled, intangible_string)
    # action_intangible.update_intangibleness(Apartment::Tenant.current, params, intangible_setting_enabled, intangible_string)
  end

  def self.create_new_product(result, current_user)
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

  def self.get_count(params)
    is_kit = 0
    supported_kit_params = ['0', '1', '-1']
    is_kit = params[:is_kit] if supported_kit_params.include?(params[:is_kit])
    conditions = { status: %w(active inactive new) }
    conditions[:is_kit] = is_kit.to_s unless is_kit == '-1'
    counts = Product.select('status,count(*) as count').where(conditions).group(:status)
    counts
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

  def generate_barcode_from_sku(sku)
    barcode = product_barcodes.new(barcode: sku.sku)
    barcode.save
    barcode
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
    response = image.save ? true : false
    response
  end

  def create_image_from_req(params, current_tenant)
    unless params[:base_64_img_upload]
      file_name = Time.now.strftime('%d_%b_%Y_%I__%M_%p')+self.id.to_s+params[:product_image].original_filename
      GroovS3.create_image(current_tenant, file_name, params[:product_image].read, params[:product_image].content_type)
      return file_name
    else
      image_content = Base64.decode64(params[:product_image][:image].to_s)
      content_type = params[:product_image][:content_type]
      file_name = Time.now.strftime('%d_%b_%Y_%I__%M_%p')+self.id.to_s+params[:product_image][:original_filename]
      GroovS3.create_image(current_tenant, file_name, image_content, content_type)
      return file_name
    end
  end

  def self.update_product_list(params, result)
    product = Product.find_by_id(params[:id])
    if product.nil?
      result = result.merge('status' => false, 'error_msg' => 'Cannot find Product')
    else
      response = product.updatelist(product, params[:var], params[:value], params[:current_user])
      errors = begin
                 response.errors.full_messages
               rescue
                 nil
               end
      result = result.merge('status' => false, 'error_msg' => errors) if errors
    end
    result
  end

  def gen_barcode_from_sku_if_intangible
    return unless is_intangible
    sku_for_barcode = product_skus.find_by_purpose('primary')
    sku_for_barcode = product_skus.first unless sku_for_barcode
    # method will not generate barcode if already exists
    sku_for_barcode.gen_barcode_from_sku_if_intangible_product if sku_for_barcode.present?
  end

  def add_product_activity(product_activity_message, username='', activity_type ='regular')
    @activity = ProductActivity.new
    @activity.product_id = self.id
    @activity.action = product_activity_message
    @activity.username = username
    @activity.activitytime = current_time_from_proper_timezone
    @activity.activity_type = activity_type
    if @activity.save
      true
    else
      false
    end
  end
end
