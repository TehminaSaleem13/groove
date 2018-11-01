class Order < ActiveRecord::Base
  belongs_to :store
  attr_accessible :customercomments, :status, :storename, :store_order_id, :store, :order_total
  attr_accessible :address_1, :address_2, :city, :country, :customer_comments, :email, :firstname,
                  :increment_id, :lastname,
                  :method, :order_placed_time, :postcode, :price, :qty, :sku, :state, :store_id, :notes_internal,
                  :notes_toPacker, :notes_fromPacker, :tracking_processed, :scanned_on, :tracking_num, :company,
                  :packing_user_id, :status_reason, :non_hyphen_increment_id, :shipping_amount, :weight_oz,
                  :custom_field_one, :custom_field_two, :traced_in_dashboard, :scanned_by_status_change,
                  :status, :scan_start_time

  #===========================================================================================
  #please update the delete_orders library if adding before_destroy or after_destroy callback
  # or adding dependent destroy for associated models
  #===========================================================================================
  has_many :order_items, :dependent => :destroy
  has_one :order_shipping, :dependent => :destroy
  has_one :order_exception, :dependent => :destroy
  has_many :order_activities, :dependent => :destroy
  has_many :order_serials, :dependent => :destroy
  has_and_belongs_to_many :order_tags
  after_update :update_inventory_levels_for_items
  before_save :perform_pre_save_checks
  # before_save :unique_order_items
  after_save :process_unprocessed_orders
  after_save :update_tracking_num_value
  after_save :delete_if_order_exist
  validates_uniqueness_of :increment_id

  include ProductsHelper
  include OrdersHelper
  include ApplicationHelper

  ALLOCATE_STATUSES = ['awaiting', 'onhold', 'serviceissue']
  UNALLOCATE_STATUSES = ['cancelled']
  SOLD_STATUSES = ['scanned']

  def customer_name
    [firstname, lastname].join(' ')
  end

  def has_store_and_warehouse?
    !self.store.nil? && self.store.ensure_warehouse?
  end

  def addactivity(order_activity_message, username='', activity_type ='regular')
    @activity = OrderActivity.new
    @activity.order_id = self.id
    @activity.action = order_activity_message
    @activity.username = username
    @activity.activitytime = current_time_from_proper_timezone
    @activity.activity_type = activity_type
    if @activity.save
      true
    else
      false
    end
  end

  def self.emit_data_for_on_demand_import(hash, order_no)
    if hash["orders"].blank?
      result = {"status" => false, "message" => "Order #{order_no} could not be found and downloaded. Please check your order source to verify this order exists."}
      GroovRealtime::emit('popup_display_for_on_demand_import', result, :tenant)
    end

  end

  def self.csv_already_imported_warning
    result = {"status" => false, "message" => "Looks like the CSV file with this name has already been imported before.<br/> If you would like to re-import this file please"  }
    GroovRealtime::emit('csv_already_imported_warning', result, :tenant)
  end

  def process_unprocessed_orders
    bulkaction = Groovepacker::Inventory::BulkActions.new
    bulkaction.process_unprocessed
    true
  end

  def update_tracking_num_value
    if self.tracking_num == ""
      self.tracking_num = nil
      self.save
    end
  end

  def addnewitems
    @order_items = OrderItem.where(:order_id => self.id)
    result = true

    @order_items.each do |item|
      #add new product if item is not added.
      if ProductSku.where(:sku => item.sku).length == 0 &&
        !item.name.nil? && item.name != '' && !item.sku.nil?
        product = Product.new
        product.name = item.name
        product.status = 'new'
        product.store_id = self.store_id
        product.store_product_id = 0

        if product.save
          product.set_product_status
          #now add skus
          @sku = ProductSku.new
          @sku.sku = item.sku
          @sku.purpose = 'primary'
          @sku.product_id = product.id
          if !@sku.save
            result &= false
          end
        end
        item.product_id = product.id
        item.save
        import_amazon_product_details(self.store_id, item.sku, item.product_id)
      else
        item.product_id = ProductSku.where(:sku => item.sku).first.product_id
        item.save
      end
    end
    result
  end

  def compute_packing_score
    100 - (self.total_scan_time.to_f / self.total_scan_count)
  end

  def set_order_to_scanned_state(username)
    self.status = 'scanned'
    self.already_scanned = true
    self.scanned_on = current_time_from_proper_timezone
    self.addactivity('Order Scanning Complete', username) if !ScanPackSetting.last.order_verification
    self.packing_score = self.compute_packing_score
    self.save
    restriction = AccessRestriction.order("created_at").last
    unless restriction.nil?
      restriction.total_scanned_shipments += 1
      restriction.save
    end

    unless Rails.env.test?
      tenant = Apartment::Tenant.current
      # if tenant == 'wagaboutit' || !Rails.env.production?
        stat_stream_obj = SendStatStream.new()
        # stat_stream_obj.build_send_stream(tenant, self.id)
        stat_stream_obj.delay(:run_at => 1.seconds.from_now, :queue => 'export_stat_stream_scheduled').build_send_stream(tenant, self.id)
      # end
    end
  end

  def has_inactive_or_new_products
    result = false

    order_items.includes(product: :product_kit_skuss).each do |order_item|
      product = order_item.product
      next if product.blank?
      product_kit_skuss = product.product_kit_skuss
      is_new_or_inactive = product.status.eql?('new') || product.status.eql?('inactive')
      # If item has 0 qty
      if is_new_or_inactive || order_item.qty.eql?(0) || product_kit_skuss.map(&:qty).index(0)
        result = true
        break
      end
    end

    result
  end

  def get_inactive_or_new_products
    products_list = []

    self.order_items.each do |order_item|
      product = order_item.product
      product_kit_skuss = product.product_kit_skuss
      next if product.blank?
      is_new_or_inactive = product.status.eql?('new') || product.status.eql?('inactive')
      if is_new_or_inactive || order_item.qty.eql?(0) || product_kit_skuss.map(&:qty).index(0)
        products_list << product.as_json(
            include: {
              product_images: {
                only: [:image]
              }
            }
          ).merge({
            sku: product.primary_sku,
            barcode: product.primary_barcode
          })
      end
    end

    products_list
  end

  def contains_zero_qty_order_item?
    order_items.find do |order_item|
      order_item.qty.eql?(0)
    end.present?
  end

  def contains_zero_qty_order_kit_item?
    order_items.find do |order_item|
      order_item.product.product_kit_skuss.map(&:qty).index(0)
    end.present?
  end

  def update_order_status
    # Implement hold orders from Groovepacker::Inventory
    result = !has_inactive_or_new_products


    result &= false if unacknowledged_activities.length > 0

    if result
      if status == 'onhold'
        self.status = 'awaiting'
        save
      end
    else
      if status == 'awaiting'
        self.status = 'onhold'
        save
      end
    end

    # isn't being used, shouldn't get called
    # self.apply_and_update_predefined_tags
  end

  def set_order_status
    result = !has_inactive_or_new_products

    result &= false if self.unacknowledged_activities.length > 0
    status = result ? 'awaiting' : 'onhold'

    if self.id.present? 
      update_column(:status, status)
      update_column(:scan_start_time, nil)
    else
      self.status = status
      self.scan_start_time = nil
      self.save
    end

    #self.apply_and_update_predefined_tags
  end

  def has_unscanned_items
    result = false
    self.reload
    self.order_items.includes(:product).each do |order_item|
      unless order_item.product.try(:is_intangible)
        if order_item.scanned_status != 'scanned'
          result |= true
          break
        end
      end
    end

    result
  end

  def contains_kit
    result = false
    self.order_items.includes(:product).each do |order_item|
      if order_item.product.is_kit == 1
        result = true
        break
      end
    end
    result
  end

  def contains_splittable_kit
    result = false
    self.order_items.includes(:product).each do |order_item|
      if order_item.product.is_kit == 1 &&
        order_item.product.kit_parsing == 'depends'
        result = true
        break
      end
    end
    result
  end

  def does_barcode_belong_to_individual_kit(barcode)
    result = false
    barcode_found = false
    product_inside_kit = false
    matched_product_id = 0

    product_barcode = ProductBarcode.where(:barcode => barcode)

    if product_barcode.length > 0
      product_barcode = product_barcode.first
      self.order_items.each do |order_item|
        if order_item.product_id == product_barcode.product.id
          barcode_found = true
          matched_product_id = order_item.product_id
        end

        if !barcode_found
          order_item.order_item_kit_products.each do |kit|
            if kit.product_kit_skus.product.id == product_barcode.product.id
              barcode_found = true
              matched_kit_id = product_kit_skus.product.id
              matched_product_id = kit.id
            end
          end
        end
      end
    end

    if barcode_found
      if Product.find(matched_product_id).kit_parsing == 'individual'
        result = true
      end
    end
    result
  end

  def should_the_kit_be_split(barcode)
    result = false
    product_inside_splittable_kit = false
    product_available_as_single_item = false
    matched_product_id = 0
    matched_order_item_id = 0
    product_barcode = ProductBarcode.where(:barcode => barcode)

    if product_barcode.length > 0
      product_barcode = product_barcode.first
    else
      product_barcode = nil
    end
    #check if barcode is present in a kit which has kitparsing of depends
    if !product_barcode.nil?
      self.order_items.includes(:product).each do |order_item|
        if order_item.product.is_kit == 1 && order_item.product.kit_parsing == 'depends' &&
          order_item.scanned_status != 'scanned'
          order_item.product.product_kit_skuss.each do |kit_product|
            if kit_product.option_product_id == product_barcode.product_id
              product_inside_splittable_kit = true
              matched_product_id = kit_product.option_product_id
              matched_order_item_id = order_item.id
              result = true
              break
            end
          end
        end
        break if product_inside_splittable_kit
      end
    end
    #if barcode is present and the matched product is also present in other non-kit
    #and unscanned order items, then the kit need not be split.
    if product_inside_splittable_kit
      self.order_items.includes(:product).each do |order_item|
        if order_item.product.is_kit == 0 && order_item.scanned_status != 'scanned'
          if order_item.product_id == matched_product_id
            product_available_as_single_item = true
            result = false
            break
          end
        end
        break if product_available_as_single_item
      end
    end

    if result
      order_item = OrderItem.find(matched_order_item_id)
      if order_item.kit_split == true

        #if current item does not belong to any of the unscanned items in the already split kits
        if order_item.should_kit_split_qty_be_increased(matched_product_id)
          if order_item.kit_split_qty + order_item.single_scanned_qty < order_item.qty
            order_item.kit_split_qty = order_item.kit_split_qty + 1
            order_item.order_item_kit_products.each do |kit_product|
              kit_product.scanned_status = 'partially_scanned'
              kit_product.save
            end
          end
        end
      else
        order_item.kit_split = true
        order_item.kit_split_qty = 1
      end
      order_item.save
      order_item.reload
    end
    result
  end

  def scanning_count
    Order.multiple_orders_scanning_count([self])[self.id]
  end

  def self.multiple_orders_scanning_count(orders)
    kits = OrderItem
      .joins(:product, order_item_kit_products: [:product_kit_skus])
      .where(
        order_id: orders.map(&:id),
        products: { is_kit: 1, kit_parsing: %w(individual)}
      )
      .select([
        'order_items.qty as order_item_qty', 'order_items.kit_split_qty',
        'order_items.kit_split_scanned_qty', 'order_items.kit_split',
        'product_kit_skus.qty as product_kit_skus_qty', 'order_id',
        'order_item_kit_products.scanned_qty as kit_product_scanned_qty',
        'kit_parsing', 'order_items.scanned_qty as order_item_scanned_qty',
        'is_kit', 'is_intangible', 'order_items.id', 'single_scanned_qty'
      ]).as_json

    single_kit_or_individual_items = OrderItem.joins(:product)
      .where(order_id: orders.map(&:id))
      .where(
        "(products.kit_parsing = 'single' AND products.is_kit IN (0,1) ) OR "\
        "(products.kit_parsing = 'individual' AND products.is_kit = 0 ) OR "\
        "(products.is_kit IS NULL ) OR "\
        "(products.kit_parsing = 'depends' AND products.is_kit IN (0,1) )"
      )
      .select([
        'is_kit', 'kit_parsing', 'order_items.qty as order_item_qty',
        'order_items.scanned_qty as order_item_scanned_qty', 'is_intangible',
        'order_items.id', 'single_scanned_qty', 'order_id'
      ]).as_json

    grouped_data =
      kits
      .push(*single_kit_or_individual_items)
      .group_by { |oi| oi['order_id'] }

    orders_scanning_count = {scanned: 0, unscanned: 0}

    grouped_data.each do |order_id, order_data|
      orders_scanning_count[order_id] =
        order_data.reduce({scanned: 0, unscanned: 0}) do |tmp_hash, data_hash|
          if data_hash['is_kit'] == 1
            case data_hash['kit_parsing']
            when 'single'
              tmp_hash[:unscanned] += (data_hash['order_item_qty'] - data_hash['order_item_scanned_qty'])
              tmp_hash[:scanned] += data_hash['order_item_scanned_qty']
            when 'individual'
              tmp_hash[:unscanned] += (
                data_hash['order_item_qty'] * data_hash['product_kit_skus_qty']
              ) - data_hash['kit_product_scanned_qty']
              tmp_hash[:scanned] += data_hash['kit_product_scanned_qty']
            when 'depends'
              if data_hash['kit_split']

                if data_hash['kit_split_qty'] > data_hash['kit_split_scanned_qty']
                  tmp_hash[:unscanned] += (
                    data_hash['kit_split_qty'] * data_hash['product_kit_skus_qty']
                  ) - data_hash['kit_product_scanned_qty']
                end

                if data_hash['order_item_qty'] > data_hash['kit_split_qty']
                  tmp_hash[:unscanned] += (
                    data_hash['order_item_qty'] - data_hash['kit_split_qty']
                  ) - (
                    data_hash['order_item_scanned_qty'] - data_hash['kit_split_scanned_qty']
                  )
                end

                if data_hash['kit_split_qty'] > 0
                  tmp_hash[:scanned] += data_hash['kit_split_scanned_qty']
                end

                if data_hash['single_scanned_qty'] != 0
                  tmp_hash[:scanned] += data_hash['single_scanned_qty']
                end
              else
                tmp_hash[:unscanned] += (data_hash['order_item_qty'] - data_hash['order_item_scanned_qty'])
                tmp_hash[:scanned] += data_hash['order_item_scanned_qty']
              end
            end
          else
            # for individual items
            unless data_hash['is_intangible'] == 1
              tmp_hash[:unscanned] += (data_hash['order_item_qty'] - data_hash['order_item_scanned_qty'] rescue 0)
            end

            tmp_hash[:scanned] += data_hash['order_item_scanned_qty']
          end
          tmp_hash
        end
    end

    orders_scanning_count
  end

  def get_unscanned_items(
    most_recent_scanned_product: nil, barcode: nil,
    order_item_status:['unscanned', 'notscanned', 'partially_scanned'],
    limit: 10, offset: 0
    )
    unscanned_list = []

    limited_order_items = order_items_with_eger_load_and_cache(order_item_status, limit, offset)

    if barcode
      barcode_in_order_item = find_unscanned_order_item_with_barcode(barcode)
      order_item_id = barcode_in_order_item.try(:id)
      unless limited_order_items.map(&:id).include?(barcode_in_order_item.try(:id))
        limited_order_items.unshift(barcode_in_order_item) if order_item_id
      end
    end
    if most_recent_scanned_product
      chek_for_recently_scanned(limited_order_items, most_recent_scanned_product)
    end
    
    limited_order_items.each do |order_item|
      if order_item.cached_product.try(:is_kit) == 1
        option_products = order_item.cached_option_products
        if order_item.cached_product.kit_parsing == 'single'
          #if single, then add order item to unscanned list
          unscanned_list.push(order_item.build_unscanned_single_item)
        elsif order_item.cached_product.kit_parsing == 'individual'
          #else if individual then add all order items as children to unscanned list
          unscanned_list.push(order_item.build_unscanned_individual_kit(option_products))
        elsif order_item.cached_product.kit_parsing == 'depends'
          if order_item.kit_split
            if order_item.kit_split_qty > order_item.kit_split_scanned_qty
              unscanned_list.push(order_item.build_unscanned_individual_kit(option_products, true))
            end
            if order_item.qty > order_item.kit_split_qty
              unscanned_item = order_item.build_unscanned_single_item(true)
              if unscanned_item['qty_remaining'] > 0
                unscanned_list.push(unscanned_item)
              end
            end
            # unscanned_qty = order_item.qty - order_item.scanned_qty
            # added_to_list_qty = true
            # unscanned_qty.times do
            #   if added_to_list_qty < unscanned_qty
            #     individual_kit_count = 0

            #     #determine no of split kits already in unscanned_list
            #     unscanned_list.each do |unscanned_item|
            #       if unscanned_item['product_id'] == order_item.product_id &&
            #           unscanned_item['product_type'] == 'individual'
            #           individual_kit_count = individual_kit_count + 1
            #       end
            #     end


            #     #unscanned list building kits
            #     if individual_kit_count < order_item.kit_split_qty
            #       unscanned_list.push(order_item.build_unscanned_individual_kit, true)
            #       added_to_list_qty = added_to_list_qty + order_item.kit_split_qty
            #     else
            #       unscanned_list.push(order_item.build_unscanned_single_item, true)
            #     end
            #   end
            # end
          else
            unscanned_item = order_item.build_unscanned_single_item
            if unscanned_item['qty_remaining'] > 0
              unscanned_list.push(unscanned_item)
            end
          end
        end
      else
        unless order_item.cached_product.is_intangible
          # add order item to unscanned list
          unscanned_item = order_item.build_unscanned_single_item
          if unscanned_item['qty_remaining'] > 0
            loc = unscanned_item["location"].present? ? unscanned_item["location"] : " " 
            placement = "%.3i" %unscanned_item['packing_placement'] rescue unscanned_item['packing_placement']
            unscanned_item["next_item"] = "#{placement}#{loc}#{unscanned_item['sku']}"
            unscanned_list.push(unscanned_item)
          end
        end
      end
    end

    unscanned_list.sort do |a, b|
      o = (a['packing_placement'] <=> b['packing_placement']);
      o == 0 ? (a['name'] <=> b['name']) : o
    end

    list = unscanned_list
    begin
      list = list.sort do |a,b|  
        a["next_item"] <=> b["next_item"]
      end
      unscanned_list = list
    rescue
      unscanned_list 
    end
  end

  def find_unscanned_order_item_with_barcode(barcode)
    return unless barcode
    (
      order_items
        .joins(product: :product_barcodes)
        .where(
          scanned_status: %w(unscanned notscanned partially_scanned),
          product_barcodes: { barcode: barcode }
        ).first
    ) || (
      order_items
        .joins(
          order_item_kit_products: {
            product_kit_skus: {
              product: :product_barcodes
            }
          }
        )
        .where(
          scanned_status: %w(unscanned notscanned partially_scanned),
          product_barcodes: { barcode: barcode }
        ).first
    ) || (
      order_items
        .joins(
          order_item_kit_products: {
            product_kit_skus: {
              option_product: :product_barcodes
            }
          }
        )
        .where(
          scanned_status: %w(unscanned notscanned partially_scanned),
          product_barcodes: { barcode: barcode }
        )
        .first
    )
  end

  def chek_for_recently_scanned(limited_order_items, most_recent_scanned_product)
    return if limited_order_items.map(&:product_id).include?(most_recent_scanned_product)

    oi = order_items.where(
      scanned_status: %w(unscanned notscanned partially_scanned),
      product_id: most_recent_scanned_product
    ).first

    if oi
      limited_order_items.unshift(oi) # unless oi.scanned_status != 'scanned'
    else
      item = order_items
        .joins(order_item_kit_products: :product_kit_skus)
        .where(
          scanned_status: %w(unscanned notscanned partially_scanned),
          product_kit_skus: { option_product_id: most_recent_scanned_product }
        )
        .first
      limited_order_items.unshift(item) unless limited_order_items.include?(item) || !item
    end
  end

  def get_scanned_items(order_item_status: ['scanned', 'partially_scanned'], limit: 10, offset: 0)
    scanned_list = []
    self.order_items_with_eger_load_and_cache(order_item_status, limit, offset).each do |order_item|
      if order_item.cached_product.is_kit == 1
        option_products = order_item.cached_option_products
        if order_item.cached_product.kit_parsing == 'single'
          #if single, then add order item to unscanned list
          scanned_list.push(order_item.build_scanned_single_item)
        elsif order_item.cached_product.kit_parsing == 'individual'
          #else if individual then add all order items as children to unscanned list
          scanned_list.push(order_item.build_scanned_individual_kit(option_products))
        elsif order_item.cached_product.kit_parsing == 'depends'
          if order_item.kit_split
            if order_item.kit_split_qty > 0
              scanned_list.push(order_item.build_scanned_individual_kit(option_products, true))
            end
            if order_item.single_scanned_qty != 0
              scanned_list.push(order_item.build_scanned_single_item(true))
            end
          else
            scanned_list.push(order_item.build_scanned_single_item)
          end
        end
      else
        # add order item to unscanned list
        scanned_list.push(order_item.build_unscanned_single_item)
      end
    end


    #transform scanned_list to move all child items into displaying as individual items
    scanned_list.each do |scanned_item|
      if scanned_item['product_type'] == 'individual'
        scanned_item['child_items'].each do |child_item|
          if child_item['scanned_qty'] > 0
            found_single_item = false
            #for each child item, check if the child item already exists in list of single items
            #in the scanned list. If so, then add this child items scanned quantity to the single items quantity
            scanned_list.each do |single_scanned_item|
              if single_scanned_item['product_type'] == 'single'
                if single_scanned_item['product_id'] == child_item['product_id']
                  single_scanned_item['scanned_qty'] = single_scanned_item['scanned_qty'] +
                    child_item['scanned_qty']
                  found_single_item = true
                end
              end
            end
            #if not found, then add this child item as a new single item
            if !found_single_item
              new_item = build_pack_item(child_item['name'], 'single', child_item['images'], child_item['sku'],
                                         child_item['qty_remaining'],
                                         child_item['scanned_qty'], child_item['packing_placement'], child_item['barcodes'],
                                         child_item['product_id'], scanned_item['order_item_id'], nil, child_item['instruction'], child_item['confirmation'], child_item['skippable'], child_item['record_serial'],
                                         child_item['box_id'], child_item['kit_product_id'])
              scanned_list.push(new_item)
            end
          end
        end
      end
    end
    scanned_list
  end

  def reset_scanned_status(current_user)
    self.order_items.each do |order_item|
      order_item.reset_scanned
    end
    self.addactivity('All scanned items removed. Order has been RESET', current_user.try(:name))
    self.order_serials.destroy_all
    self.set_order_status
  end

  def addtag(tag_id)
    result = false

    tag = OrderTag.find(tag_id)

    if !tag.nil? && (!self.order_tags.include? tag)
      self.order_tags << tag
      self.save
      result = true
    end

    result
  end

  def removetag(tag_id)
    result = false

    tag = OrderTag.find(tag_id)

    if !tag.nil? && (self.order_tags.include? tag)
      self.order_tags.delete(tag)
      self.save
      result = true
    end

    result
  end

  def apply_and_update_predefined_tags

    #apply contains new tag, if any of the order items contain new products
    contains_new_tag = OrderTag.where(:name => 'Contains New')
    contains_new_tag = contains_new_tag.first if contains_new_tag.length > 0
    if !contains_new_tag.nil?
      contains_new = false

      self.order_items.each do |order_item|
        if !order_item.product.nil? && order_item.product.status == 'new'
          contains_new = true
        end
      end

      # if contains_new
      #   self.addtag(contains_new_tag.id)
      # else
      #   self.removetag(contains_new_tag.id)
      # end
    end

    #apply contains inactive tag, if any of the order items contain inactive products
    contains_inactive_tag = OrderTag.where(:name => 'Contains Inactive')
    contains_inactive_tag = contains_inactive_tag.first if contains_inactive_tag.length > 0
    if !contains_inactive_tag.nil?
      contains_inactive = false

      self.order_items.each do |order_item|
        if !order_item.product.nil? && order_item.product.status == 'inactive'
          contains_inactive = true
          break
        end
      end

      # if contains_inactive
      #   self.addtag(contains_inactive_tag.id)
      # else
      #   self.removetag(contains_inactive_tag.id)
      # end
    end

    self.save

  end

  def get_items_count
    count = 0
    unless self.order_items.empty?
      self.order_items.each do |item|
        count = count + item.qty unless item.qty.nil?
      end
    end
    count
  end

  def update_inventory_levels_for_items
    changed_hash = self.changes
    #TODO: remove this from here as soon as possible.
    # Very slow way to ensure inventory always gets allocated
    Groovepacker::Inventory::Orders.allocate(self)
    if changed_hash['status'].nil?
      return true
    end
    initial_status = changed_hash['status'][0]
    final_status = changed_hash['status'][1]
    if ALLOCATE_STATUSES.include?(initial_status)
      if UNALLOCATE_STATUSES.include?(final_status)
        # Allocate -> unallocate = deallocate inv
        Groovepacker::Inventory::Orders.deallocate(self, true)
      elsif SOLD_STATUSES.include?(final_status)
        # Allocate -> sold = sell inventory
        Groovepacker::Inventory::Orders.sell(self)
      end
    elsif UNALLOCATE_STATUSES.include?(initial_status)
      if ALLOCATE_STATUSES.include?(final_status)
        # Unallocate -> allocate = Allocate inventory
        Groovepacker::Inventory::Orders.allocate(self, true)
      end
    elsif SOLD_STATUSES.include?(initial_status)
      if ALLOCATE_STATUSES.include?(final_status)
        Groovepacker::Inventory::Orders.unsell(self)
        user = User.find_by_id(GroovRealtime.current_user_id)
        self.reset_scanned_status(user)
      end
    end
    self.update_column(:reallocate_inventory, false)
    true
  end

  def perform_pre_save_checks
    self.non_hyphen_increment_id = non_hyphenated_string(self.increment_id.to_s).squish
    self.increment_id = self.increment_id.to_s.squish!
    if self.status.nil?
      self.status = 'onhold'
    end
  end

  def scanned_items_count
    count = 0
    self.order_items.each do |item|
      if item.try(:product).try(:is_kit) == 1
        if item.product.kit_parsing == 'depends'
          count = count + item.single_scanned_qty
          item.order_item_kit_products.each do |kit_product|
            count = count + kit_product.scanned_qty
          end
        elsif item.product.kit_parsing == 'individual'
          item.order_item_kit_products.each do |kit_product|
            count = count + kit_product.scanned_qty
          end
        else
          count = count + item.scanned_qty
        end
      else
        count = count + item.scanned_qty
      end
    end
    count
  end

  def clicked_items_count
    count = 0
    self.order_items.each do |item|
      if item.product.is_kit == 1
        if item.product.kit_parsing == 'depends'
          count = count + item.clicked_qty
          item.order_item_kit_products.each do |kit_product|
            count = count + kit_product.clicked_qty
          end
        elsif item.product.kit_parsing == 'individual'
          item.order_item_kit_products.each do |kit_product|
            count = count + kit_product.clicked_qty
          end
        else
          count = count + item.clicked_qty
        end
      else
        count = count + item.clicked_qty
      end
    end
    count
  end

  def unacknowledged_activities
    order_activities.
      where('activity_type in (:types)', types: 'deleted_item').
      where(acknowledged: false)
  end

  def add_item_to_order(product)
    order_item = OrderItem.new
    order_item.product = product
    order_item.name = product.name
    unless product.product_skus.empty?
      order_item.sku = product.product_skus.first.sku
    end
    order_item.qty = 1
    order_item.order = self
    order_item.save
    self.update_order_status
  end

  def destroy_exceptions(result, current_user, tenant)
    if order_exception.destroy
      addactivity("Order Exception Cleared", current_user.name)
      stat_stream_obj = SendStatStream.new()
      stat_stream_obj.delay(:run_at => 1.seconds.from_now, :queue => 'clear_order_exception_#{self.id}').send_order_exception(self.id, tenant)
      #stat_stream_obj.send_order_exception(self.id, tenant)
    else
      result['status'] &= false
      result['messages'].push('Error clearing exceptions')
    end
    return result
  end

  # def self.duplicate_selected_orders(orders, current_user, result)
  #   orders.each do |order|
  #     neworder = order.duplicate_single_order(current_user, result)

  #     unless neworder.persisted?
  #       result['status'] = false
  #       result['error_messages'] = neworder.errors.full_messages
  #     else
  #       #add activity
  #       Order.add_activity_to_new_order(neworder, order.order_items, current_user)
  #     end
  #   end
  #   return result
  # end

  def self.add_activity_to_new_order(neworder, order_items, username)
    order_items.each do |order_item|
      Order.create_new_order_item(neworder, order_item)
    end
    neworder.addactivity("Order duplicated", username)
  end

  def self.create_new_order_item(neworder, order_item)
    neworder_item = OrderItem.new
    neworder_item.order_id = neworder.id
    neworder_item.product_id = order_item.product_id
    neworder_item.qty = order_item.qty
    neworder_item.name = order_item.name
    neworder_item.price = order_item.price
    neworder_item.row_total = order_item.row_total
    neworder_item.save
  end

  # def duplicate_single_order(current_user, result)
  #   neworder = self.dup
  #   index = 0
  #   temp_increment_id = ''

  #   begin
  #     temp_increment_id = self.increment_id + "(duplicate"+index.to_s+ ")"
  #     neworder.increment_id = temp_increment_id
  #     orderslist = Order.where(:increment_id => temp_increment_id)
  #     index = index + 1
  #   end while orderslist.present?
  #   neworder.save(:validate => false)
  #   return neworder
  # end

  def set_traced_in_dashboard
    self.traced_in_dashboard = true
    self.save!
  end

  def partially_load_order_item(order_item_status, limit, offset)
    if order_item_status == ["scanned", "partially_scanned"]
      order_items.where(scanned_status: order_item_status).order('updated_at desc').offset(offset)
    else
      order_items.where(scanned_status: order_item_status).limit(limit).offset(offset)
    end
  end

  def order_items_with_eger_load_and_cache(order_item_status, limit, offset)
    # key = "order_items_#{id}_was_egar_loaded"
    limited_order_items = partially_load_order_item(order_item_status, limit, offset)
    if !(
      %w(lairdsuperfood).include?(Apartment::Tenant.current)
    ) && (
      limited_order_items.map(&:keys?).include? true
    )
      limited_order_items
    else
      # Rails.cache.write(key, true, expires_in: 30.minutes)
      limited_order_items.includes(
        order_item_kit_products: [
          product_kit_skus: [
            product: [
              :product_skus, :product_images,
              :product_barcodes
            ]
          ]
        ],
        product: [
          :product_skus, :product_images,
          :product_barcodes
        ]
      )
    end
  rescue
    delete_cached_order_items_keys
    retry
  end

  def delete_cached_order_items_keys
    order_items.map(&:delete_cache)
  end

  def delete_if_order_exist
    orders = Order.where(increment_id: increment_id)
    self.destroy if orders.count > 1
  end

  def unique_order_items
    self.order_items = self.order_items.uniq_by {|obj| obj.product_id} 
  end

  def destroy_boxes
    Box.where(order_id: self.id).destroy_all
  end

  def get_boxes_data
    boxes = Box.where(order_id: self.id)
    order_item_boxes = []
    boxes.each do |box|
      order_item_boxes << box.order_item_boxes
    end

    list =  []
    order_item_boxes.flatten.each do |o|
      data1 = {}
      order_item_kit_product = OrderItemKitProduct.find(o.kit_id)
      product_kit_sku = order_item_kit_product.product_kit_skus
      product = Product.find(product_kit_sku.option_product_id)
      data1 = { product_name: product.name ,qty:  o.item_qty, box: o.box.id  }
      list << data1
    end  
    list = list.group_by { |d| d[:box] }
    result = { box: boxes.as_json(only: [:id, :name]), order_item_boxes: order_item_boxes.flatten, list: list   }
  end
end
