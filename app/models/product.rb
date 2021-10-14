class Product < ActiveRecord::Base
  extend ProductClassMethodsHelper
  include ProductsHelper
  include ProductMethodsHelper
  belongs_to :store

  # attr_accessible :name,
  #                 :product_type,
  #                 :store_product_id,
  #                 :status,
  #                 :packing_instructions,
  #                 :packing_instructions_conf,
  #                 :is_skippable,
  #                 :packing_placement,
  #                 :pack_time_adj,
  #                 :is_kit,
  #                 :kit_parsing,
  #                 :disable_conf_req,
  #                 :store,
  #                 :weight,
  #                 :add_to_any_order,
  #                 :is_intangible,
  #                 :base_sku,
  #                 :product_receiving_instructions,
  #                 :second_record_serial,
  #                 :record_serial,
  #                 :click_scan_enabled,
  #                 :is_skippable,
  #                 :add_to_any_order,
  #                 :type_scan_enabled,
  #                 :custom_product_1,
  #                 :custom_product_2,
  #                 :custom_product_3,
  #                 :custom_product_display_1,
  #                 :custom_product_display_2,
  #                 :custom_product_display_3,
  #                 :fnsku, :asin, :fba_upc, :isbn, :ean,
  #                 :supplier_sku, :avg_cost, :count_group

  has_many :product_skus, dependent: :destroy
  has_many :product_cats, dependent: :destroy
  has_many :product_barcodes,:class_name => 'ProductBarcode', dependent: :destroy
  has_many :product_images,:class_name => 'ProductImage', dependent: :destroy
  has_many :product_kit_skuss, :class_name => 'ProductKitSkus',  dependent: :destroy
  has_many :product_inventory_warehousess,:class_name => 'ProductInventoryWarehouses',  dependent: :destroy
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
                 :primary_sku, :product_inventory_warehousess
  after_save :delete_cache
  after_save :check_and_update_status_updated_column

  SINGLE_KIT_PARSING = 'single'.freeze
  DEPENDS_KIT_PARSING = 'depends'.freeze
  INDIVIDUAL_KIT_PARSING = 'individual'.freeze

  SINGLE_SCAN_STATUSES = [SINGLE_KIT_PARSING, DEPENDS_KIT_PARSING].freeze
  INDIVIDUAL_SCAN_STATUSES = [INDIVIDUAL_KIT_PARSING].freeze

  def check_inventory_warehouses
    if Product.find(self.id).product_inventory_warehousess.empty?
      inventory = ProductInventoryWarehouses.new
      inventory.product_id = id
      inventory.inventory_warehouse = InventoryWarehouse.where(is_default: true).first
      inventory.save
    end
    true
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
      .includes(:order_item_kit_products, :product, order: [order_items: :product])
    end

    if status != 'inactive' || force_from_inactive_state
      result = true

      result &= false if name.nil? || name == ''

      result &= false if product_skus.empty?

      result &= false if product_barcodes.empty?

      unless base_sku.nil?
        result &= false if base_product.status == 'inactive' || base_product.status == 'new'
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
          result &= false if !option_product.nil? && option_product.status != 'active'
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
      unless @order_items.blank?
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
            # .includes(order: [order_items: [:product, :order_item_kit_products]])

          #result_kit = true
          @kit_products.each do |kit_product|
            if kit_product.product.status != 'inactive'
              kit_product.product.update_product_status(nil, {
                multi_product_order_items: multi_product_order_items
              })
            end
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
    orders = Order.eager_load(:order_items).where("order_items.product_id IN (?)", updated_products.map(&:id))
    return if orders.length<1
    action = GrooveBulkActions.where(identifier: "order", activity: "status_update", status: "pending").first
    action = GrooveBulkActions.new(identifier: "order", activity: "status_update", status: "pending") if action.blank?
    action.total = orders.count
    action.save
  end

  def check_and_update_status_updated_column
    process_order_item if self.saved_changes["status"].present?
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
    result &= false if (@skus = ProductSku.where(product_id: id)).empty?
    result &= false if (@barcodes = ProductBarcode.where(product_id: id)).empty?
    result &= false unless unacknowledged_kit_activities.empty?
    self.status = result ? 'active' : 'new'
    save
  end

  def should_scan_as_single_product?
    !should_scan_as_individual_items?
  end

  def should_scan_as_individual_items?
    is_kit == 1
  end

  # def get_total_avail_loc
  #   total_avail_loc = 0
  #   product_inventory_warehousess.each { |inv_wh| total_avail_loc += inv_wh.available_inv }
  #   # product_inventory_warehousess.each do |inv_wh|
  #   #   total_avail_loc += inv_wh.available_inv
  #   # end
  #   total_avail_loc
  # end

  # def get_total_sold_qty
  #   total_sold_qty = 0
  #   product_inventory_warehousess.all.each { |inv_wh| total_sold_qty += inv_wh.sold_inv }
  #   # product_inventory_warehousess.all.each do |inv_wh|
  #   #   total_sold_qty += inv_wh.sold_inv
  #   # end
  #   total_sold_qty
  # end

  # def get_weight
  #   format = get_show_weight_format
  #   weight_gms = weight * 28.349523125
  #   case format
  #   when 'lb'
  #     return (weight / 16).round(2)
  #   when 'oz'
  #     return weight
  #   when 'kg'
  #     return (weight_gms / 1000).round(3)
  #   else
  #     return weight_gms.round
  #   end
  #   # if format == 'lb'
  #   #   return (weight / 16).round(2)
  #   # elsif format == 'oz'
  #   #   return weight
  #   # elsif format == 'kg'
  #   #   return (weight_gms / 1000).round(3)
  #   # else
  #   #   return weight_gms.round
  #   # end
  # end

  # def get_shipping_weight
  #   format = get_show_weight_format
  #   weight_gms = shipping_weight * 28.349523125
  #   case format
  #   when 'lb'
  #     return (shipping_weight / 16).round(2)
  #   when 'oz'
  #     return shipping_weight
  #   when 'kg'
  #     return (weight_gms / 1000).round(3)
  #   else
  #     return weight_gms.round
  #   end
  #   # if format == 'lb'
  #   #   return (shipping_weight / 16).round(2)
  #   # elsif format == 'oz'
  #   #   return shipping_weight
  #   # elsif format == 'kg'
  #   #   return (weight_gms / 1000).round(3)
  #   # else
  #   #   return weight_gms.round
  #   # end
  # end

  def get_weight(type = nil)
    weight_type = type == 'shipping' ? shipping_weight : weight
    format = get_show_weight_format
    weight_gms = weight_type * 28.349523125
    case format
    when 'lb'
      return (weight_type / 16).round(2)
    when 'oz'
      return weight_type
    when 'kg'
      return (weight_gms / 1000).round(3)
    else
      return weight_gms.round
    end
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

  def base_product
    if base_sku.present?
      base_product_sku = ProductSku
                         .where(sku: base_sku)
                         .includes(
                           product: [
                             :product_inventory_warehousess, :product_skus,
                             :product_cats, :product_barcodes, :product_images
                           ]
                         ).first
      return base_product_sku.try :product
    else
      return self
    end
  end

  def primary_barcode=(value, permit_same_barcode = nil)
    primary = primary_barcode_obj
    primary = product_barcodes.new if primary.nil?
    primary.order = 0
    primary.barcode = value
    errors.add(:base, "Barcode #{primary.barcode} already exists") unless permit_same_barcode ? primary.save(validate: false) : primary.save
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

  # def create_or_update_productsku(sku, order, status = nil, db_sku=nil,current_user)
  #   product_sku = status == 'new' ? ProductSku.new : db_sku
  #   product_sku.product.add_product_activity( "The SKU of this item was changed from #{product_sku.sku} to #{sku['sku']} ",current_user.username) if (status != 'new' && sku['sku'] != product_sku.sku)
  #   product_sku.sku = sku['sku']
  #   product_sku.purpose = sku['purpose']
  #   product_sku.product_id = id unless product_sku.persisted?
  #   product_sku.order = order
  #   product_sku.product.add_product_activity( "The SKU #{product_sku.sku} was added to this item",current_user.username) if status == 'new'
  #   response = product_sku.save ? true : false
  #   response
  # end

  # def create_or_update_productbarcode(barcode, order, status = nil, db_barcode=nil, current_user)
  #   product_barcode = status == 'new' ? ProductBarcode.new : db_barcode
  #   product_barcode.product.add_product_activity( "The barcode of this item was changed from #{product_barcode.barcode} to #{barcode['barcode']} ",current_user.username) if (status != 'new' && barcode['barcode'] != product_barcode.barcode)
  #   product_barcode.barcode = barcode['barcode']
  #   product_barcode.product_id = id unless product_barcode.persisted?
  #   product_barcode.order = order
  #   product_barcode.product.add_product_activity( "The barcode #{product_barcode.barcode} was added to this item",current_user.username) if status == 'new'
  #   response = product_barcode.save ? true : false
  #   response
  # end

  def generate_barcode_from_sku(sku)
    barcode = product_barcodes.new(barcode: sku.sku)
    barcode.save
    barcode
  end
end
