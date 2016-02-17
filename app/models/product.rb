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
                  :product_receiving_instructions

  has_many :product_skus, :dependent => :destroy
  has_many :product_cats, :dependent => :destroy
  has_many :product_barcodes, :dependent => :destroy
  has_many :product_images, :dependent => :destroy
  has_many :product_kit_skuss, :dependent => :destroy
  has_many :product_inventory_warehousess, :dependent => :destroy
  has_many :order_serial
  has_many :order_items
  has_many :product_kit_activities, dependent: :destroy
  has_many :product_lots
  has_one :sync_option

  after_save :check_inventory_warehouses

  SINGLE_KIT_PARSING = 'single'
  DEPENDS_KIT_PARSING = 'depends'
  INDIVIDUAL_KIT_PARSING = 'individual'

  SINGLE_SCAN_STATUSES = [SINGLE_KIT_PARSING, DEPENDS_KIT_PARSING]
  INDIVIDUAL_SCAN_STATUSES = [INDIVIDUAL_KIT_PARSING]


  def self.to_csv(folder, options= {})
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
        headers= []
        if ident == :products
          ProductsHelper.products_csv(model.all, csv)
        else
          headers= model.column_names.dup

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
    if self.product_inventory_warehousess.all.length == 0
      inventory = ProductInventoryWarehouses.new
      inventory.product_id = self.id
      inventory.inventory_warehouse = InventoryWarehouse.where(:is_default => true).first
      inventory.save
    end

    true
  end

  def update_product_status (force_from_inactive_state = false)
    # original_status = self.status
    if self.status != 'inactive' || force_from_inactive_state
      result = true

      result &= false if (self.name.nil? or self.name == '')

      result &= false if self.product_skus.length == 0

      result &= false if self.product_barcodes.length == 0

      unless self.base_sku.nil?
        if base_product.status == 'inactive' || base_product.status == 'new'
          result &= false
        end
      end

      #if kit it should contain kit products as well
      if self.is_kit == 1
        result &= false if self.product_kit_skuss.length == 0
        self.product_kit_skuss.each do |kit_product|
          option_product = Product.find(kit_product.option_product_id)
          if !option_product.nil? &&
            option_product.status != 'active'
            result &= false
          end
        end
        result &= false if unacknowledged_kit_activities.length > 0
      end

      if result
        self.status = 'active'
        self.save
      else
        self.status = 'new'
        self.save
      end

      # unless self.status == original_status
      # for non kit products, update all kits product statuses where the
      # current product is an item of the kit
      if self.is_kit == 0
        @kit_products = ProductKitSkus.where(:option_product_id => self.id)
        result_kit = true
        @kit_products.each do |kit_product|
          if kit_product.product.status != 'inactive'
            kit_product.product.update_product_status
          end
        end
      end

      if result && self.base_sku.nil?
        products = Product.where(:base_sku => self.primary_sku)
        unless products.empty?
          products.each do |child_product|
            child_product.update_product_status
          end
        end
      end

      #update order items status from onhold to awaiting
      @order_items = OrderItem.where(product_id: self.id, scanned_status: 'notscanned')
      @order_items.each do |item|
        item.order.update_order_status unless item.order.nil? or !['awaiting', 'onhold'].include?(item.order.status)
      end
      # end
    else
      #update order items status from onhold to awaiting
      @order_items = OrderItem.where(product_id: self.id, scanned_status: 'notscanned')
      @order_items.each do |item|
        item.order.update_order_status unless item.order.nil? or !['awaiting', 'onhold'].include?(item.order.status)
      end
    end
    result
  end

  def update_due_to_inactive_product
    if self.status == 'inactive'
      kit_products = ProductKitSkus.where(:option_product_id => self.id)
      unless kit_products.empty?
        kit_products.each do |kit_product|
          if kit_product.product.status != 'inactive'
            kit_product.product.status = 'new'
            kit_product.product.save
            order_items = OrderItem.where(product_id: kit_product.product.id, scanned_status: 'notscanned')
            order_items.each do |item|
              item.order.update_order_status unless item.order.nil?
            end
          end
        end
      end
      @order_items = OrderItem.where(product_id: self.id, scanned_status: 'notscanned')
      @order_items.each do |item|
        item.order.update_order_status unless item.order.nil?
      end
    end
  end

  def set_product_status
    result = true

    @skus = ProductSku.where(:product_id => self.id)
    result &= false if @skus.length == 0

    @barcodes = ProductBarcode.where(:product_id => self.id)
    result &= false if @barcodes.length == 0

    result &= false if unacknowledged_kit_activities.length > 0

    if result
      self.status = 'active'
    else
      self.status = 'new'
    end
    self.save
  end

  def should_scan_as_single_product?
    return !self.should_scan_as_individual_items?
  end

  def should_scan_as_individual_items?
    return self.is_kit == 1
  end

  def get_total_avail_loc
    total_avail_loc = 0
    self.product_inventory_warehousess.each do |inv_wh|
      total_avail_loc = total_avail_loc + inv_wh.available_inv
    end
    total_avail_loc
  end


  def get_total_sold_qty
    total_sold_qty = 0
    self.product_inventory_warehousess.all.each do |inv_wh|
      total_sold_qty += inv_wh.sold_inv
    end
    total_sold_qty
  end

  def get_weight
    format = get_show_weight_format
    weight_gms = self.weight * 28.349523125
    if format == 'lb'
      return (self.weight / 16).round(2)
    elsif format == 'oz'
      return self.weight
    elsif format == 'kg'
      return (weight_gms / 1000).round(3)
    else
      return weight_gms.round
    end
  end

  def get_shipping_weight
    format = get_show_weight_format
    weight_gms = self.shipping_weight * 28.349523125
    if format == 'lb'
      return (self.shipping_weight / 16).round(2)
    elsif format == 'oz'
      return self.shipping_weight
    elsif format == 'kg'
      return (weight_gms / 1000).round(3)
    else
      return weight_gms.round
    end
  end

  def get_inventory_warehouse_info(inventory_warehouse_id)
    product_inventory_warehouses =
      ProductInventoryWarehouses.where(:inventory_warehouse_id => inventory_warehouse_id).
        where(:product_id => self.id)
    product_inventory_warehouses.first
  end

  # provides primary sku if exists
  def primary_sku
    self.product_skus.order('product_skus.order ASC').first.sku unless self.product_skus.order('product_skus.order ASC').first.nil?
  end

  def primary_sku=(value)
    primary = self.product_skus.order('product_skus.order ASC').first
    if primary.nil?
      primary = self.product_skus.new
    end
    primary.order = 0
    primary.sku = value
    unless primary.save
      self.errors.add(:base, "Sku #{primary.sku} already exists")
    end
  end

  # provides primary image if exists
  def primary_image
    self.product_images.order('product_images.order ASC').first.image unless self.product_images.order('product_images.order ASC').first.nil?
  end

  def primary_image=(value)
    primary = self.product_images.order('product_images.order ASC').first
    if primary.nil?
      primary = self.product_images.new
    end
    primary.order = 0
    primary.image = value
    primary.save
  end

  # provides primary barcode if exists
  def primary_barcode
    self.product_barcodes.order('product_barcodes.order ASC').first.barcode unless self.product_barcodes.order('product_barcodes.order ASC').first.nil?
  end

  def base_product
    unless self.base_sku.nil?
      base_product_sku = ProductSku.where(:sku => self.base_sku).first unless ProductSku.where(:sku => self.base_sku).empty?
      return base_product_sku.product unless base_product_sku.nil?
    else
      return self
    end
  end

  def primary_barcode=(value)
    primary = self.product_barcodes.order('product_barcodes.order ASC').first
    if primary.nil?
      primary = self.product_barcodes.new
    end
    primary.order = 0
    primary.barcode = value
    unless primary.save
      self.errors.add(:base, "Barcode #{primary.barcode} already exists")
    end

  end

  # provides primary category if exists
  def primary_category
    self.product_cats.first.category unless self.product_cats.first.nil?
  end

  def primary_category=(value)
    primary = self.product_cats.first
    if primary.nil?
      primary = self.product_cats.new
    end
    primary.category = value
    primary.save
  end

  def primary_warehouse
    self.product_inventory_warehousess.where(inventory_warehouse_id:
                                               InventoryWarehouse.where(:is_default => true).first.id).first
  end

  def unacknowledged_kit_activities
    product_kit_activities.
      where('activity_type in (:types)', types: 'deleted_item').
      where(acknowledged: false)
  end

  def is_active
    self.status == 'active' ? 'TRUE' : 'FALSE'
  end

  def get_product_weight(weight)
    unless self.weight_format.nil?
      if self.weight_format=='lb'
        @lbs = 16 * weight.to_f
      elsif self.weight_format=='oz'
        @oz = weight.to_f
      elsif self.weight_format=='kg'
        @kgs = 1000 * weight.to_f
        @kgs * 0.035274
      else
        @gms = weight.to_f
        @gms * 0.035274
      end
    else
      if GeneralSetting.get_product_weight_format=='lb'
        @lbs = 16 * weight.to_f
      elsif GeneralSetting.get_product_weight_format=='oz'
        @oz = weight.to_f
      elsif GeneralSetting.get_product_weight_format=='kg'
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
      unless scan_pack_settings.intangible_string.nil? || (scan_pack_settings.intangible_string.strip.equal? (''))
        intangible_string = scan_pack_settings.intangible_string
        intangible_strings = intangible_string.split(",")
        intangible_strings.each do |string|
          if (self.name.include? (string)) || sku_contains_string(string)
            return true
          end
        end
      end
    end
    return false
  end

  def sku_contains_string(string)
    product_skus = self.product_skus
    product_skus.each do |product_sku|
      if product_sku.sku.include? (string)
        return true
      end
    end
    return false
  end

  def get_show_weight_format
    unless self.weight_format.nil?
      return self.weight_format
    else
      return GeneralSetting.get_product_weight_format
    end
  end

  def create_or_update_productcat(category)
    product_cat = ProductCat.find_or_initialize_by_id(category["id"])
    product_cat.category = category["category"]
    product_cat.product_id = self.id unless product_cat.persisted?
    response = product_cat.save ? true : false
    return response
  end

  def create_or_update_productimage(image, order)
    product_image = ProductImage.find_or_initialize_by_id(image["id"])
    product_image.image = image["image"]
    product_image.caption = image["caption"]
    product_image.product_id = self.id unless product_image.persisted?
    product_image.order = order
    response = product_image.save ? true : false
    return response
  end

  def create_or_update_productkitsku(kit_product)
    actual_product = ProductKitSkus.find_by_option_product_id_and_product_ide(kit_product["option_product_id"], self.id)
    return unless actual_product  
    actual_product.qty = kit_product["qty"]
    actual_product.packing_order = kit_product["packing_order"]
    actual_product.save
  end

  def create_or_update_productsku(sku, order, status=nil)
    product_sku = status=='new' ? ProductSku.new : ProductSku.find(sku["id"])

    product_sku.sku = sku["sku"]
    product_sku.purpose = sku["purpose"]
    product_sku.product_id = self.id unless product_sku.persisted?
    product_sku.order = order
    response = product_sku.save ? true : false
    return response
  end

  def create_or_update_productbarcode(barcode, order, status=nil)
    product_barcode = status=='new' ? ProductBarcode.new : ProductBarcode.find(barcode["id"])
    
    product_barcode.barcode = barcode["barcode"]
    product_barcode.product_id = self.id unless product_barcode.persisted?
    product_barcode.order = order
    response = product_barcode.save ? true : false
    return response
  end

  def self.update_action_intangibleness(params)
    action_intangible = Groovepacker::Products::ActionIntangible.new
    scan_pack_setting = ScanPackSetting.all.first
    intangible_setting_enabled = scan_pack_setting.intangible_setting_enabled
    intangible_string = scan_pack_setting.intangible_string
    action_intangible.delay(:run_at => 1.seconds.from_now).update_intangibleness(Apartment::Tenant.current, params, intangible_setting_enabled, intangible_string)
    # action_intangible.update_intangibleness(Apartment::Tenant.current, params, intangible_setting_enabled, intangible_string)
  end

  def self.create_new_product(result, current_user)
    if current_user.can?('add_edit_products')
      product = Product.new
      product.name = "New Product"
      product.store_id = Store.where(:store_type => 'system').first.id
      product.save
      product.store_product_id = product.id
      product.save
      result['product'] = product
    else
      result['status'] = false
      result['messages'].push('You do not have enough permissions to create a product')
    end
    return result
  end

  def self.get_count(params)
    is_kit = 0
    supported_kit_params = ['0', '1', '-1']
    is_kit = params[:is_kit] if supported_kit_params.include?(params[:is_kit])
    conditions = {:status => ['active', 'inactive', 'new']}
    conditions[:is_kit] = is_kit.to_s unless is_kit == '-1'
    counts = Product.select('status,count(*) as count').where(conditions).group(:status)
    return counts
  end

  def generate_barcode(result)
    return result unless product_barcodes.blank?
    sku = product_skus.first
    return result if sku.nil?
    barcode = generate_barcode_from_sku(sku)
    unless barcode.errors.blank?
      result['status'] &= false
      result['messages'].push(barcode.errors.full_messages)
    end
    update_product_status
    return result
  end

  def generate_barcode_from_sku(sku)
    barcode = product_barcodes.new(:barcode => sku.sku)
    barcode.save
    return barcode
  end

end
