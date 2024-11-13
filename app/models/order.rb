# frozen_string_literal: true

class Order < ApplicationRecord
  belongs_to :store, optional: true
  belongs_to :origin_store, optional: true
  # attr_accessible :customercomments, :status, :storename, :store_order_id, :store, :order_total
  # attr_accessible :address_1, :address_2, :city, :country, :customer_comments, :email, :firstname, :increment_id, :lastname,:method, :order_placed_time, :postcode, :price, :qty, :sku, :state, :store_id, :notes_internal, :notes_toPacker, :notes_fromPacker, :tracking_processed, :scanned_on, :tracking_num, :company, :packing_user_id, :status_reason, :non_hyphen_increment_id, :shipping_amount, :weight_oz, :custom_field_one, :custom_field_two, :traced_in_dashboard, :scanned_by_status_change, :status, :scan_start_time, :last_modified, :last_suggested_at, :prime_order_id, :split_from_order_id, :source_order_ids, :cloned_from_shipment_id

  #===========================================================================================
  # please update the delete_orders library if adding before_destroy or after_destroy callback
  # or adding dependent destroy for associated models
  #===========================================================================================
  has_many :order_items, dependent: :destroy
  has_one :order_shipping, dependent: :destroy
  has_one :tote, dependent: :nullify
  has_one :order_exception, dependent: :destroy
  has_one :shipstation_label_data, dependent: :delete
  has_many :order_activities, dependent: :destroy
  has_many :order_serials, dependent: :destroy
  has_many :packing_cams, dependent: :destroy
  has_many :shipping_labels, dependent: :destroy
  has_and_belongs_to_many :order_tags
  belongs_to :packing_user, class_name: 'User', optional: true

  before_save :assign_increment_id
  after_update :update_inventory_levels_for_items
  before_save :perform_pre_save_checks
  # before_save :unique_order_items
  after_save :process_unprocessed_orders
  after_save :update_tracking_num_value
  after_save :delete_if_order_exist, unless: :check_for_duplicate
  after_save :perform_after_scanning_tasks
  after_create :create_origin_store
  after_save :trigger_webhooks

  # validates :increment_id, :uniqueness => { :scope => :increment_id}, :if => :check_for_duplicate
  validates :increment_id, uniqueness: { unless: :check_for_duplicate }

  attr_accessor :scan_pack_v2, :pull_inv

  extend OrderClassMethodsHelper
  include ProductsHelper
  include OrdersHelper
  include OrderMethodsHelper
  include ApplicationHelper

  serialize :ss_label_data, JSON

  ALLOCATE_STATUSES = %w[awaiting onhold serviceissue].freeze
  UNALLOCATE_STATUSES = ['cancelled'].freeze
  SOLD_STATUSES = ['scanned'].freeze
  RECENT_ORDERS_CONDITION = "orders.order_placed_time >= ?".freeze

  scope :awaiting, -> { where(status: 'awaiting') }
  scope :partially_scanned, -> { awaiting.joins(:order_items).where.not(order_items: { scanned_qty: 0 }).distinct }
  scope :awaiting_without_partially_scanned, -> { awaiting.where.not(id: partially_scanned.ids) }
  scope :filtered_by_status, lambda { |statuses|
    return all if statuses.include?('all')

    statuses.delete('partiallyscanned') if statuses.include?('partiallyscanned')

    statuses = [statuses] unless statuses.is_a?(Array)
    where(status: statuses.map(&:to_s)) if statuses.present?
  }

  scope :filter_partially_scanned, lambda { |statuses|
    if statuses.include?('partiallyscanned') && !statuses.include?('awaiting')
      includes(:order_items)
        .where('EXISTS (SELECT 1 FROM order_items WHERE order_items.order_id = orders.id AND order_items.scanned_qty > 0)')
        .where(status: 'awaiting')
    end
  }
  scope :filtered_sorted_orders, lambda { |sort_key, sort_order, limit, offset, status_filter, status_filter_text, query_add, params|
    return all if sort_key.blank?

    case sort_key
    when 'store_name'
      joins(:store).order("stores.name #{sort_order}")
    when 'itemslength'
      includes(:order_items)
        .select('orders.*, (SELECT SUM(order_items.qty) FROM order_items WHERE order_items.order_id = orders.id) AS count').group('orders.id').order("count #{sort_order}")
    when 'tote'
      joins(:tote).order("totes.name #{sort_order}")
    else
      includes(:tote, :store, :order_tags).order("#{sort_key} #{sort_order}")
    end
  }

  scope :filter_all_status, lambda { |filters|
    filter_partially_scanned(filters).merge(Order.filtered_by_status(filters))
  }
  scope :filter_by_qty, lambda { |operator, value|
    if value.present? && !value.is_a?(Hash)
      includes(:order_items)
        .select('orders.*, (SELECT SUM(order_items.qty) FROM order_items WHERE order_items.order_id = orders.id) AS count')
        .having("count #{operator} ?", value)
    end
  }
  scope :filter_by_increment_id, lambda { |operator, value|
    where("increment_id #{operator} ?", value) if value.present?
  }
  scope :filter_by_notes_internal, lambda { |operator, value|
    where("notes_internal #{operator} ?", value) if value.present?
  }
  scope :filter_by_recipient, lambda { |operator, value|
    where("CONCAT(firstname, '', lastname) #{operator} ?", value) if value.present?
  }
  scope :filter_by_store, lambda { |operator, value|
    joins(:store).where('stores.name LIKE ?', value) if value.present?
  }
  scope :filter_by_custom_field_one, lambda { |operator, value|
    where("custom_field_one #{operator} ?", value) if value.present?
  }
  scope :filter_by_custom_field_two, lambda { |operator, value|
    where("custom_field_two #{operator} ?", value) if value.present?
  }
  scope :filter_by_tracking_num, lambda { |operator, value|
    where("tracking_num #{operator} ?", value) if value.present?
  }
  scope :filter_by_country, lambda { |operator, value|
    where("country #{operator} ?", value) if value.present?
  }
  scope :filter_by_city, lambda { |operator, value|
    where("city #{operator} ?", value) if value.present?
  }
  scope :filter_by_email, lambda { |operator, value|
    where("email #{operator} ?", value) if value.present?
  }
  scope :filter_by_tote, lambda { |operator, value|
    joins(:tote).where('tote.name LIKE ?', value) if value.present?
  }
  scope :filter_by_date, lambda { |operator, value|
    value = DateTime.strptime(value, '%m-%d-%Y') if value.is_a?(String)
    where("DATE(order_placed_time) #{operator} ?", value) if value.present? && operator.present?
  }
  scope :with_tags, ->(tag_names, shouldFilterIncludeTags) {
    joins(:order_tags).where(order_tags: { name: tag_names }).distinct if tag_names.present? && shouldFilterIncludeTags.to_b
  }
  scope :without_tags, ->(tag_names, shouldFilterIncludeTags) {
    joins(:order_tags).where.not(order_tags: { name: tag_names }).distinct if tag_names.present? && !shouldFilterIncludeTags.to_b
  }

  scope :by_packing_user_name, ->(usernames) {
    if usernames.present?
      usernames_array = usernames.split(',')

      if usernames_array.include?('unassigned')
        left_outer_joins(:packing_user)
          .where('users.username IN (?) OR users.id IS NULL', usernames_array.reject { |u| u == 'unassigned' })
      else
        joins(:packing_user).where(users: { username: usernames_array })
      end
    end
  }

  scope :filter_by_last_days, lambda { |days|
    if days.present? && days != 'all_day'
      case days
      when 'today'
        where('order_placed_time >= ?', DateTime.now.beginning_of_day)
      when 'this_week'
        where('order_placed_time >= ?', DateTime.now.beginning_of_week)
      when 'last_week'
        where('order_placed_time >= ? AND order_placed_time < ?', DateTime.now.beginning_of_week - 1.week, DateTime.now.beginning_of_week)
      when 'this_month'
        where('order_placed_time >= ?', DateTime.now.beginning_of_month)
      when 'last_month'
        where('order_placed_time >= ? AND order_placed_time < ?', DateTime.now.beginning_of_month - 1.month, DateTime.now.beginning_of_month)
      else
        where('order_placed_time >= ?', DateTime.now - days.to_i.days)
      end
    end
  }
  scope :check_date_range, lambda { |date_range_str|
    date_range = begin
      JSON.parse(date_range_str)
    rescue StandardError
      {}
    end
    start_date = date_range['start_date']
    end_date = date_range['end_date']

    within_date_range({ start_date:, end_date: }, 'inrange')
  }

  scope :within_date_range, lambda { |date_range_object, operator|
    if date_range_object.is_a?(Hash) && date_range_object[:start_date].present? && date_range_object[:end_date].present?
      start_date = date_range_object[:start_date]
      end_date = date_range_object[:end_date]
      start_date = DateTime.strptime(start_date, '%m-%d-%Y') if start_date.is_a?(String) && start_date != ''
      end_date = DateTime.strptime(end_date, '%m-%d-%Y') if end_date.is_a?(String) && end_date != ''

      if operator == 'inrange'
        if start_date.present? && end_date.present?
          where('DATE(order_placed_time) >= ? AND DATE(order_placed_time) <= ?', start_date, end_date)
        end
      elsif operator == 'notinrange'
        if start_date.present? && end_date.present?
          where('DATE(order_placed_time) < ? OR DATE(order_placed_time) > ?', start_date, end_date)
        end
      end
    end
  }
  scope :within_number_range, lambda { |number_range_object, sort_value|
    start_value = number_range_object[:start_value]
    end_value = number_range_object[:end_value]
    if number_range_object.present? && number_range_object.is_a?(Hash)
      if sort_value.present? && (start_value.present? && end_value.present?)
        return having('count >= CAST(? AS SIGNED) AND count <= CAST(? AS SIGNED)', start_value, end_value)
      end

      if start_value.present? && end_value.present?
        joins(:order_items)
          .select('orders.*, SUM(order_items.qty) AS count')
          .group('orders.id')
          .having('count >= CAST(? AS SIGNED) AND count <= CAST(? AS SIGNED)', start_value, end_value)
      end
    end
  }

  def assign_increment_id
    return if increment_id.present?

    self.increment_id = Order.get_temp_increment_id
  end

  def check_for_duplicate
    (store.store_type == 'ShippingEasy' && store.shipping_easy_credential.allow_duplicate_id) || (store.store_type == 'Shipstation API 2' && store.shipstation_rest_credential.allow_duplicate_order) || (store.store_type == 'Veeqo' && store.veeqo_credential.allow_duplicate_order)
  end

  def customer_name
    [firstname, lastname].join(' ')
  end

  def has_store_and_warehouse?
    !store.nil? && store.ensure_warehouse?
  end

  def addactivity(order_activity_message, username = '', on_ex = nil, activity_type = 'regular')
    @activity = OrderActivity.new
    @activity.order_id = id
    @activity.action = order_activity_message
    @activity.username = username
    @activity.activitytime = current_time_from_proper_timezone
    @activity.activity_type = activity_type
    @activity.user_id = User.find_by_username(username).try(:id)
    @activity.user_id = User.find_by_name(username).try(:id) if @activity.user_id.nil?
    @activity.platform = on_ex unless on_ex.nil?
    @activity.save
  end

  def process_unprocessed_orders
    # bulkaction = Groovepacker::Inventory::BulkActions.new
    # bulkaction.process_unprocessed
    if begin
      Tenant.find_by_name(Apartment::Tenant.current).try(:delayed_inventory_update)
    rescue StandardError
      nil
    end
      Groovepacker::Inventory::BulkActions.new.process_unprocessed(id)
    else
      Groovepacker::Inventory::BulkActions.new.process_unprocessed
    end
    true
  end

  def update_tracking_num_value
    return unless tracking_num == ''

    self.tracking_num = nil
    save
  end

  def addnewitems
    @order_items = OrderItem.where(order_id: id)
    result = true

    @order_items.each do |item|
      # add new product if item is not added.
      if ProductSku.where(sku: item.sku).empty? && !item.name.nil? && item.name != '' && !item.sku.nil?
        add_new_product_for_item(item, result)
      else
        item.product_id = ProductSku.where(sku: item.sku).first.product_id
        item.save
      end
    end
    result
  end

  def compute_packing_score
    100 - (total_scan_time.to_f / total_scan_count)
  end

  def set_order_to_scanned_state(username, on_ex = nil)
    self.status = 'scanned'
    self.already_scanned = true
    self.scanned_on = current_time_from_proper_timezone
    addactivity('Order Scanning Complete', username, on_ex) unless ScanPackSetting.last.order_verification
    self.packing_score = compute_packing_score
    self.post_scanning_flag = nil
    self.packing_user_id = nil
    # Remove tote assignment
    Tote.where(order_id: id).update_all(order_id: nil, pending_order: false)
    save
    update_access_restriction
    tenant = Apartment::Tenant.current
    return unless !Rails.env.test? && Tenant.where(name: tenant).last.groovelytic_stat

    SendStatStream.new.delay(run_at: 1.second.from_now, queue: 'export_stat_stream_scheduled_' + tenant, priority: 95).build_send_stream(
      tenant, id
    )
  end

  def trigger_webhooks
    return unless saved_change_to_status? && status == 'scanned'

    Webhooks::Orders::OrderScanWebhookService.trigger_scanned_order_webhooks(id)
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

    result &= false unless unacknowledged_activities.empty?

    if result
      if status == 'onhold'
        self.status = 'awaiting'
        save
      end
    elsif status == 'awaiting'
      self.status = 'onhold'
      save
    end
    # isn't being used, shouldn't get called
    # self.apply_and_update_predefined_tags
  end

  def set_order_status
    result = !has_inactive_or_new_products

    result &= false unless unacknowledged_activities.empty?
    status = result ? 'awaiting' : 'onhold'

    if id.present?
      update_column(:status, status)
      update_column(:scan_start_time, nil)
    else
      self.status = status
      self.scan_start_time = nil
      save
    end

    # self.apply_and_update_predefined_tags
  end

  def has_unscanned_items
    result = false
    reload
    order_items.includes(:product).each do |order_item|
      next if order_item.product.try(:is_intangible)
      next unless order_item.scanned_status != 'scanned'

      result |= true
      break
    end

    result
  end

  def contains_kit
    result = false
    order_items.includes(:product).each do |order_item|
      if order_item.product.is_kit == 1
        result = true
        break
      end
    end
    result
  end

  def contains_splittable_kit
    result = false
    order_items.includes(:product).each do |order_item|
      next unless order_item.product.is_kit == 1 &&
                  order_item.product.kit_parsing == 'depends'

      result = true
      break
    end
    result
  end

  def scanning_count
    Order.multiple_orders_scanning_count([self])[id]
  end

  def reset_scanned_status(current_user, on_ex = nil)
    order_items.includes([:order_item_kit_products]).each(&:reset_scanned)
    addactivity('All scanned items removed. Order has been RESET', current_user.try(:name), on_ex)
    order_serials.destroy_all
    destroy_boxes
    set_order_status
    update_columns(post_scanning_flag: nil, clicked_scanned_qty: 0)
  end

  def add_tag(imported_tag)
    tag = OrderTag.find_or_create_by(source_id: imported_tag['tagId'].to_s, name: imported_tag['name'])
    tag.groovepacker_tag_origin = 'STATION'
    tag.color = imported_tag['color'] if imported_tag['color'].present?
    add_order_tag(tag)
  end

  def add_tag_from_shopify(imported_tags)
    result = false
    imported_tags.split(', ').each do |item|
      tag = OrderTag.find_or_create_by(name: item, color: '#95BF47')
      tag.groovepacker_tag_origin = 'SHOPIFY'
      result ||= add_order_tag(tag)
    end
    result
  end

  def removetag(tag_id)
    result = false

    tag = OrderTag.find(tag_id)

    if !tag.nil? && (order_tags.include? tag)
      order_tags.delete(tag)
      save
      result = true
    end

    result
  end

  def get_items_count
    count = 0
    return count if order_items.empty?

    order_items.each do |item|
      count += item.qty unless item.qty.nil?
    end
    count
  end

  def update_inventory_levels_for_items
    changed_hash = saved_changes
    # TODO: remove this from here as soon as possible.
    # Very slow way to ensure inventory always gets allocated
    Groovepacker::Inventory::Orders.allocate(self)

    return true if changed_hash['status'].nil?

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
      # Unallocate -> allocate = Allocate inventory
      Groovepacker::Inventory::Orders.allocate(self, true) if ALLOCATE_STATUSES.include?(final_status)
    elsif SOLD_STATUSES.include?(initial_status)
      if ALLOCATE_STATUSES.include?(final_status)
        perform_pull_inv_or_unsell
        if order_items.select do |o|
             o.product.is_intangible == false
           end.count == order_items.where(scanned_status: 'scanned').select do |o|
             o.product.is_intangible == false
           end.count
          user = User.find_by_id(GroovRealtime.current_user_id)
          reset_scanned_status(user)
        end
      end
    end
    update_column(:reallocate_inventory, false)
    true
  end

  def perform_pull_inv_or_unsell
    if pull_inv == true
      Groovepacker::Inventory::Orders.allocate(self, false,
                                               true)
    else
      Groovepacker::Inventory::Orders.unsell(self)
    end
  end

  def perform_pre_save_checks
    self.non_hyphen_increment_id = non_hyphenated_string(increment_id.to_s).squish
    self.increment_id = increment_id.to_s.squish!
    self.status = 'onhold' if status.nil?
  end

  def scanned_items_count
    count = 0
    order_items.each do |item|
      if item.try(:product).try(:is_kit) == 1
        if item.product.kit_parsing == 'depends'
          count += item.single_scanned_qty
          item.order_item_kit_products.each do |kit_product|
            count += kit_product.scanned_qty
          end
        elsif item.product.kit_parsing == 'individual'
          item.order_item_kit_products.each do |kit_product|
            count += kit_product.scanned_qty
          end
        else
          count += item.scanned_qty
        end
      else
        count += item.scanned_qty
      end
    end
    count
  end

  def clicked_items_count
    count = 0
    order_items.each do |item|
      if item.product.is_kit == 1
        if item.product.kit_parsing == 'depends'
          count += item.clicked_qty
          item.order_item_kit_products.each do |kit_product|
            count += kit_product.clicked_qty
          end
        elsif item.product.kit_parsing == 'individual'
          item.order_item_kit_products.each do |kit_product|
            count += kit_product.clicked_qty
          end
        else
          count += item.clicked_qty
        end
      else
        count += item.clicked_qty
      end
    end
    count
  end

  def unacknowledged_activities
    order_activities.where('activity_type in (:types)', types: 'deleted_item').where(acknowledged: false)
  end

  def add_item_to_order(product)
    order_item = OrderItem.new
    order_item.product = product
    order_item.name = product.name
    order_item.sku = product.product_skus.first.sku unless product.product_skus.empty?
    order_item.qty = 1
    order_item.order = self
    order_item.save
    update_order_status
  end

  def destroy_exceptions(result, current_user, tenant)
    if order_exception.destroy
      addactivity('Order Exception Cleared', current_user.name)
      stat_stream_obj = SendStatStream.new
      stat_stream_obj.delay(run_at: 1.second.from_now, queue: 'clear_order_exception_#{self.id}', priority: 95).send_order_exception(
        id, tenant
      )
    else
      result['status'] &= false
      result['messages'].push('Error clearing exceptions')
    end
    result
  end

  def set_traced_in_dashboard
    self.traced_in_dashboard = true
    save!
  end

  def partially_load_order_item(order_item_status, limit, offset)
    # if order_item_status == ["scanned", "partially_scanned"]
    #   order_items.where(scanned_status: order_item_status).order('updated_at desc').offset(offset)
    # else
    #   order_items.where(scanned_status: order_item_status).limit(limit).offset(offset)
    # end
    all_order_items = order_items.where(scanned_status: order_item_status)
    if order_item_status == %w[scanned
                               partially_scanned]
      all_order_items.order('updated_at desc').offset(offset)
    else
      all_order_items.limit(limit).offset(offset)
    end
  end

  def order_items_with_eger_load_and_cache(order_item_status, limit, offset)
    # key = "order_items_#{id}_was_egar_loaded"
    limited_order_items = partially_load_order_item(order_item_status, limit, offset)
    if !%w[lairdsuperfood].include?(Apartment::Tenant.current) && (limited_order_items.map(&:keys?).include? true)
      limited_order_items
    else
      # Rails.cache.write(key, true, expires_in: 30.minutes)
      limited_order_items.includes(
        order_item_kit_products: [
          product_kit_skus: [
            product: %i[product_skus product_images product_barcodes product_inventory_warehousess]
          ]
        ],
        product: %i[product_skus product_images product_barcodes product_inventory_warehousess]
      )
    end
  rescue StandardError
    delete_cached_order_items_keys
    retry
  end

  def delete_cached_order_items_keys
    order_items.map(&:delete_cache)
  end

  def delete_if_order_exist
    orders = Order.where(increment_id:)
    destroy if orders.count > 1
  end

  def unique_order_items
    self.order_items = order_items.uniq_by(&:product_id)
  end

  def destroy_boxes
    Box.where(order_id: id).destroy_all
  end

  def scanned?
    status == 'scanned'
  end

  def label_data
    shipstation_label_data&.content || {}
  end

  private

  def add_order_tag(tag)
    if tag && !order_tags.include?(tag)
      order_tags << tag
      save
      true
    else
      false
    end
  end

  def perform_after_scanning_tasks
    return unless saved_changes['status'].present? && status == 'scanned'

    if store&.store_type == 'Shipstation API 2' && store&.shipstation_rest_credential&.add_gpscanned_tag
      add_gp_scanned_tag
    end

    add_gp_scanned_tag_in_shopify if store&.store_type == 'Shopify' && store&.shopify_credential&.add_gp_scanned_tag
  end

  def create_origin_store
    return unless label_data.present? || store.store_type == 'ShippingEasy'

    origin_store_id = if store.store_type == 'ShippingEasy'
                        self.origin_store_id
                      else
                        label_data.dig('advancedOptions', 'storeId')
                      end

    recent_order_details = "#{firstname} #{lastname}  - #{increment_id}"
    orig_store = OriginStore.find_by(origin_store_id:)
    if orig_store.present?
      orig_store.update!(recent_order_details:)
    elsif origin_store_id.present?
      orig_store = OriginStore.create!(store_id:, origin_store_id:,
                                       recent_order_details:, store_name: "Store-#{origin_store_id}")
    end
    update(origin_store_id: orig_store&.id)
  end
end
