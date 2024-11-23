# frozen_string_literal: true

module OrderMethodsHelper
  include ActionView::Helpers::NumberHelper

  def add_gp_scanned_tag
    ss_credential = store&.shipstation_rest_credential
    return unless ss_credential&.add_gpscanned_tag

    ss_client = Groovepacker::ShipstationRuby::Rest::Client.new(ss_credential.api_key, ss_credential.api_secret)
    ss_client.delay(run_at: 1.seconds.from_now, queue: "add_gp_scanned_tag_ss_#{Apartment::Tenant.current}", priority: 79).add_gp_scanned_tag(store_order_id)
  end

  def add_gp_scanned_tag_in_shopify
    shopify_credential = store.shopify_credential
    return unless shopify_credential&.add_gp_scanned_tag

    shopify_credential.class.delay(run_at: 1.seconds.from_now, queue: "add_gp_scanned_tag_shopify_#{Apartment::Tenant.current}", priority: 83).add_tag_to_order(Apartment::Tenant.current, shopify_credential.id, store_order_id)
  end

  def get_se_old_shipments(result_order)
    return result_order unless store.store_type == 'ShippingEasy'

    se_old_shipments = []

    prime_orders = Order.where(store_order_id: split_from_order_id) if split_from_order_id.present?
    shipments = Order.where(prime_order_id: split_from_order_id.to_i).where('cloned_from_shipment_id IS NULL OR cloned_from_shipment_id = ?', '') if split_from_order_id.present? && prime_orders.any?
    if shipments.blank?
      shipments = Order.where(split_from_order_id: prime_order_id).to_a if prime_order_id.present? && (prime_order_id == store_order_id)
      shipments << self if shipments.try(:any?)
    end
    se_old_split_shipments = true if shipments.try(:any?)

    shipments = Order.where(store_order_id: source_order_ids.split(',').map(&:to_i)) unless se_old_split_shipments || !source_order_ids.present?
    se_old_combined_shipments = shipments.try(:any?) && !se_old_split_shipments ? true : false

    if se_old_split_shipments || se_old_combined_shipments
      shipments.each do |shipment|
        if shipment.status == 'scanned'
          current_status = "Imported #{shipment.created_at.strftime('%B %e %Y %l:%M %p')} - Scanned #{shipment.scanned_on.strftime('%B %e %Y %l:%M %p')}"
        else
          shipment_status = begin
                              (shipment.scanning_count[:scanned].to_i > 0 ? 'Partial Scanned' : 'Unscanned')
                            rescue StandardError
                              'Unscanned'
                            end
          current_status = "Imported #{shipment.created_at.strftime('%B %e %Y %l:%M %p')} - #{shipment_status}"
        end
        se_old_shipments << { id: shipment.id, increment_id: shipment.increment_id, status: current_status, store_order_id: shipment.store_order_id, firstname: shipment.firstname, lastname: shipment.lastname, tracking_num: shipment.tracking_num, order_placed_time: shipment.order_placed_time, items_count: shipment.get_items_count }
      end
      result_order['se_old_split_shipments'] = se_old_split_shipments ? se_old_shipments : nil
      result_order['se_old_combined_shipments'] = se_old_combined_shipments ? se_old_shipments : nil
    else
      all_shipments = { shipments: [] }
      shipments = Order.includes(:order_items).where('orders.prime_order_id = ? AND orders.status != ? AND split_from_order_id != ? AND (cloned_from_shipment_id IS NULL OR cloned_from_shipment_id = ?)', prime_order_id, 'scanned', '', '') if prime_order_id.present? && Order.where('split_from_order_id != ? AND (cloned_from_shipment_id IS NULL OR cloned_from_shipment_id = ?)', '', '').where(prime_order_id: prime_order_id).count > 1
      return result_order if shipments.blank? || shipments.count == 1

      all_shipments[:present] = true
      shipments.each do |shipment|
        all_shipments[:shipments] << { id: shipment.id, increment_id: shipment.increment_id, store_order_id: shipment.store_order_id, firstname: shipment.firstname, lastname: shipment.lastname, tracking_num: shipment.tracking_num, order_placed_time: shipment.order_placed_time, items_count: shipment.get_items_count }
      end
      result_order['se_all_shipments'] = all_shipments
    end

    result_order
  end

  def has_inactive_or_new_products
    result = false
    order_items.includes(product: :product_kit_skuss).each do |order_item|
      product = order_item.product
      next if product.blank?

      product_kit_skuss = product.product_kit_skuss
      is_new_or_inactive = product.status.eql?('new') || product.status.eql?('inactive')
      # If item has 0 qty
      if is_new_or_inactive || (order_item.qty.eql?(0) && order_item.skipped_qty.eql?(0)) || product_kit_skuss.map(&:qty).index(0)
        result = true
        break
      end
    end
    result
  end

  def get_inactive_or_new_products
    products_list = []
    order_items.each do |order_item|
      product = order_item.product
      product_kit_skuss = product.product_kit_skuss
      next if product.blank?

      is_new_or_inactive = product.status.eql?('new') || product.status.eql?('inactive')
      next unless is_new_or_inactive || (order_item.qty.eql?(0) && order_item.skipped_qty.eql?(0)) || product_kit_skuss.map(&:qty).index(0)

      products_list << product.as_json(
        include: {
          product_images: {
            only: [:image]
          }
        }
      ).merge(sku: product.primary_sku, barcode: product.primary_barcode)
      products_list = check_and_add_inactive_kit_items(products_list, product_kit_skuss)
    end
    products_list
  end

  def check_and_add_inactive_kit_items(products_list, product_kit_skuss)
    return products_list if product_kit_skuss.blank?

    product_kit_skuss.each do |kit_sku|
      kit_sku_product = kit_sku.option_product
      is_new_or_inactive = kit_sku_product.status.eql?('new') || kit_sku_product.status.eql?('inactive')
      next unless is_new_or_inactive

      products_list << kit_sku_product.as_json(
        include: {
          product_images: {
            only: [:image]
          }
        }
      ).merge(sku: kit_sku_product.primary_sku, barcode: kit_sku_product.primary_barcode)
    end
    products_list
  end

  def should_the_kit_be_split(barcode)
    result = false
    product_inside_splittable_kit = false
    product_available_as_single_item = false
    matched_product_id = 0
    matched_order_item_id = 0
    product_barcodes = ProductBarcode.where(barcode: barcode)

    # check if barcode is present in a kit which has kitparsing of depends
    if product_barcodes.any?
      order_items.includes(:product).each do |order_item|
        if order_item.product.is_kit == 1 && order_item.product.kit_parsing == 'depends' &&
           order_item.scanned_status != 'scanned'
          order_item.product.product_kit_skuss.each do |kit_product|
            next unless kit_product.option_product_id.in? product_barcodes.pluck(:product_id)

            product_inside_splittable_kit = true
            matched_product_id = kit_product.option_product_id
            matched_order_item_id = order_item.id
            result = true
            break
          end
        end
        break if product_inside_splittable_kit
      end
    end
    # if barcode is present and the matched product is also present in other non-kit
    # and unscanned order items, then the kit need not be split.
    if product_inside_splittable_kit
      order_items.includes(:product).each do |order_item|
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

        # if current item does not belong to any of the unscanned items in the already split kits
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

  def get_unscanned_items(
    most_recent_scanned_product: nil, barcode: nil,
    order_item_status: %w[unscanned notscanned partially_scanned],
    limit: 10, offset: 0
  )
    unscanned_list = []

    limited_order_items = order_items_with_eger_load_and_cache(order_item_status, limit, offset).to_a

    if barcode
      barcode_in_order_item = find_unscanned_order_item_with_barcode(barcode)
      order_item_id = barcode_in_order_item.try(:id)
      unless limited_order_items.map(&:id).include?(barcode_in_order_item.try(:id))
        limited_order_items.unshift(barcode_in_order_item) if order_item_id
      end
    end
    chek_for_recently_scanned(limited_order_items, most_recent_scanned_product) if most_recent_scanned_product
    update_unscanned_list(limited_order_items, unscanned_list, scan_pack_v2)

    unscanned_list = unscanned_list.sort_by { |a| a['packing_placement'] }

    list = unscanned_list
    begin
      grouped_by_packing_placement = list.group_by { |x| x['packing_placement'] }

      sorted_array = []

      grouped_by_packing_placement.each_value do |array|
        sorted_array << array.sort_by do |x|
          location = x['location'].to_s
          if location.empty?
            [0, x['sku'][0].downcase]
          else
            [1, location.chars.map { |c| c =~ /\W/ ? [0, c] : (c =~ /\d/ ? [1, c.to_i] : [2, c]) }]
          end
        end
      end
      list = sorted_array.flatten
      unscanned_list = list
    rescue StandardError
      unscanned_list
    end
    ScanPackSetting.last.scanning_sequence == 'kits_sequence' ? unscanned_list.sort_by { |row| (row['partially_scanned'] ? 0 : 1) } : unscanned_list
  end

  def find_unscanned_order_item_with_barcode(barcode)
    return unless barcode

    order_item = order_items.joins(product: :product_barcodes).where(
      scanned_status: %w[unscanned notscanned partially_scanned],
      product_barcodes: { barcode: barcode }
    ).first
    order_item ||= order_items
                   .joins(
                     order_item_kit_products: {
                       product_kit_skus: {
                         product: :product_barcodes
                       }
                     }
                   )
                   .where(
                     scanned_status: %w[unscanned notscanned partially_scanned],
                     product_barcodes: { barcode: barcode }
                   ).first
    order_item ||= order_items
                   .joins(
                     order_item_kit_products: {
                       product_kit_skus: {
                         option_product: :product_barcodes
                       }
                     }
                   )
                   .where(
                     scanned_status: %w[unscanned notscanned partially_scanned],
                     product_barcodes: { barcode: barcode }
                   )
                   .first
  end

  def chek_for_recently_scanned(limited_order_items, most_recent_scanned_product)
    return if limited_order_items.map(&:product_id).include?(most_recent_scanned_product)

    oi = order_items.where(
      scanned_status: %w[unscanned notscanned partially_scanned],
      product_id: most_recent_scanned_product
    ).first

    if oi
      limited_order_items.unshift(oi) # unless oi.scanned_status != 'scanned'
    else
      item = order_items
             .joins(order_item_kit_products: :product_kit_skus)
             .where(
               scanned_status: %w[unscanned notscanned partially_scanned],
               product_kit_skus: { option_product_id: most_recent_scanned_product }
             )
             .first
      limited_order_items.unshift(item) unless limited_order_items.include?(item) || !item
    end
  end

  def get_scanned_items(order_item_status: %w[scanned partially_scanned], limit: 10, offset: 0, is_reload: false)
    scanned_list = []
    order_items_with_eger_load_and_cache(order_item_status, limit, offset).each do |order_item|
      if(!order_item.cached_product.nil?)
        update_scanned_list(order_item, scanned_list)
      end
    end

    # transform scanned_list to move all child items into displaying as individual items
    scanned_list.each do |scanned_item|
      next unless scanned_item['product_type'] == 'individual'

      scanned_item['child_items'].reverse!
      scanned_item['child_items'].each do |child_item|
        next unless child_item['scanned_qty'] > 0

        found_single_item = false
        # for each child item, check if the child item already exists in list of single items
        # in the scanned list. If so, then add this child items scanned quantity to the single items quantity
        scanned_list.each do |single_scanned_item|
          next unless single_scanned_item['product_type'] == 'single'

          next unless single_scanned_item['product_id'] == child_item['product_id'] && is_reload == false

          single_scanned_item['scanned_qty'] = single_scanned_item['scanned_qty'] +
                                               child_item['scanned_qty']
          found_single_item = true
        end
        # if not found, then add this child item as a new single item
        next if found_single_item

        new_item = build_pack_item(child_item['name'], 'single', child_item['images'], child_item['sku'],
                                   child_item['qty_remaining'],
                                   child_item['scanned_qty'], child_item['packing_placement'], child_item['barcodes'],
                                   child_item['product_id'], scanned_item['order_item_id'], nil, child_item['instruction'], child_item['confirmation'], child_item['skippable'], child_item['record_serial'],
                                   child_item['box_id'], child_item['kit_product_id'], child_item ['updated_at'])
        scanned_list.push(new_item)
      end
    end
    scanned_list.sort! { |a, b| b['updated_at'] <=> a['updated_at'] }
  end

  def get_boxes_data
    boxes = Box.where(order_id: id)
    order_item_boxes = []
    boxes.each do |box|
      order_item_boxes << box.order_item_boxes
    end

    list = []
    order_item_boxes.flatten.each do |o|
      next unless (order_item_kit_product = OrderItemKitProduct.find_by_id(o.kit_id))

      product_kit_sku = order_item_kit_product.product_kit_skus
      product = Product.find(product_kit_sku.option_product_id)
      data1 = { product_name: product.name, qty: o.item_qty, box: o.box.id, kit_id: o.kit_id, sku: product.product_skus.first.sku, barcode: product.product_barcodes.first.barcode, primary_location: product.product_inventory_warehousess.first.location_primary  }
      list << data1
    end
    list = list.group_by { |d| d[:box] }
    result = { box: boxes.as_json(only: %i[id name]), order_item_boxes: order_item_boxes.flatten, list: list }
  end

  def ss_label_order_data(skip_trying: false, params: {})
    ss_rest_credential = store.shipstation_rest_credential
    order_ss_label_data = label_data || {}
    direct_print_data = {}
    ss_client = Groovepacker::ShipstationRuby::Rest::Client.new(ss_rest_credential.api_key, ss_rest_credential.api_secret)
    general_settings = GeneralSetting.last
    order = ss_client.get_order(order_ss_label_data["orderId"].to_s)
    direct_print_data = try_creating_label if !skip_trying && ss_rest_credential.skip_ss_label_confirmation && (!Box.where(order_id: id).many? || general_settings.per_box_shipping_label_creation == 'per_box_shipping_label_creation_none')
    if direct_print_data[:status]
      order_ss_label_data['direct_printed'] = true
      order_ss_label_data['direct_printed_url'] = direct_print_data[:url]
      order_ss_label_data[:dimensions] = '4x6'
      return order_ss_label_data
    end
    order_ss_label_data['shipping_labels'] = shipping_labels
    order_ss_label_data['shipments'] = ss_client.get_shipments_by_order_id(store_order_id)
    order_ss_label_data['order_number'] = increment_id
    order_ss_label_data['credential_id'] = ss_rest_credential.id
    order_ss_label_data['skip_ss_label_confirmation'] = ss_rest_credential.skip_ss_label_confirmation
    order_ss_label_data['orderId'] ||= store_order_id
    order_ss_label_data['available_carriers'] = begin
                                                  JSON.parse(ss_client.list_carriers.body)
                                                rescue StandardError
                                                  []
                                                end
    order_ss_label_data['fromPostalCode'] = User.current.try(:warehouse_postcode).present? ? User.current.warehouse_postcode : ss_rest_credential.postcode
    order_ss_label_data['toCountry'] = country
    order_ss_label_data['toState'] = state
    order_ss_label_data['toPostalCode'] = postcode
    order_ss_label_data['toName'] = customer_name
    order_ss_label_data['toAddress1'] = address_1
    order_ss_label_data['toAddress2'] = address_2
    order_ss_label_data['toCity'] = city
    order_ss_label_data['label_shortcuts'] = ss_rest_credential.label_shortcuts
    order_ss_label_data['presets'] = ss_rest_credential.presets
    order_ss_label_data['weight'] = { 'value' => nil, 'units' => 'ounces', 'WeightUnits' => 1 } if order_ss_label_data['weight'].nil?
    order_ss_label_data['dimensions'] = { 'length' => nil, 'width' => nil, 'height' => nil, 'units' => 'cm' } if order_ss_label_data['dimensions'].nil?
    order_ss_label_data['reprint_dimensions'] = '4x6'
    order_ss_label_data['available_carriers'].each do |carrier|
      carrier['visible'] = !(ss_rest_credential.disabled_carriers.include? carrier['code'])
      carrier['expanded'] = !(ss_rest_credential.contracted_carriers.include? carrier['code'])
      next unless should_show_carrier(params[:app], carrier, order_ss_label_data['carrierCode'])

      data = {
        carrierCode: carrier['code'],
        fromPostalCode: order_ss_label_data['fromPostalCode'],
        toCity: order_ss_label_data['toCity'],
        toCountry: country,
        toState: state,
        toPostalCode: postcode,
        confirmation: order_ss_label_data['confirmation']
      }
      data = data.merge(weight: order_ss_label_data['weight']) if order_ss_label_data['weight']
      data = data.merge(residential: order["shipTo"]["residential"])
      data = data.merge(dimensions: order_ss_label_data['dimensions'])  if order_ss_label_data['dimensions'].present? && order_ss_label_data['dimensions']['units'].present? && order_ss_label_data['dimensions']['length'].present? && order_ss_label_data['dimensions']['width'].present? && order_ss_label_data['dimensions']['height'].present?
      should_fetch_rates = should_show_carrier(params[:app], carrier, nil)

      rate_error = false
      if should_fetch_rates
        rates_response = ss_client.get_ss_label_rates(data.to_h)
        carrier['errors'] = rates_response.first(3).map { |res| res = res.join(': ') }.join('<br>') unless rates_response.ok?
        rate_error = !rates_response.ok?
      end
      next if rate_error

      carrier['rates'] = should_fetch_rates ? JSON.parse(rates_response.body) : []
      carrier['services'] = JSON.parse(ss_client.list_services(carrier['code']).body) if carrier['code'] == 'stamps_com'
      carrier['packages'] = JSON.parse(ss_client.list_packages(carrier['code']).body) if carrier['code'] == 'stamps_com'
      if order_ss_label_data['carrierCode'].present? && carrier['code'] == order_ss_label_data['carrierCode']
        order_ss_label_data['carrier'] = carrier
        order_ss_label_data['service'] = carrier['services'].select { |c| c['code'] == order_ss_label_data['serviceCode'] }.first if order_ss_label_data['serviceCode'].present? && carrier['code'] == 'stamps_com'
        order_ss_label_data['package'] = carrier['packages'].select { |c| c['code'] == order_ss_label_data['packageCode'] }.first if order_ss_label_data['packageCode'].present? && carrier['code'] == 'stamps_com'
      end
      carrier['rates'].map { |r| r['carrierCode'] = carrier['code'] }
      carrier['rates'].map { |r| r['cost'] = number_with_precision((r['shipmentCost'] + r['otherCost']), precision: 2) }
      carrier['rates'].sort_by! { |hsh| hsh['cost'].to_f }
      carrier['rates'].map do |r|
        r['visible'] = !(begin
                                                  (ss_rest_credential.disabled_rates[carrier['code']].include? r['serviceName'])
                         rescue StandardError
                           false
                                                end)
      end
      next unless carrier['code'] == 'stamps_com'

      carrier['rates'].each do |rate|
        rate['packageCode'] = begin
                                carrier['packages'].select { |h| h['name'] == rate['serviceName'].split(' - ').last }.first['code']
                              rescue StandardError
                                nil
                              end
      end
    end
    order_ss_label_data
  rescue StandardError => e
    puts e
  end

  def try_creating_label
    return { status: false } unless check_valid_label_data

    default_ship_date = Time.current.in_time_zone('Pacific Time (US & Canada)').strftime('%a, %d %b %Y')
    ship_date = if label_data['shipDate'].present?
                  shipping_date = ActiveSupport::TimeZone['Pacific Time (US & Canada)'].parse(label_data['shipDate'].to_s).strftime('%a, %d %b %Y')
                  shipping_date.to_date < default_ship_date.to_date ? default_ship_date : shipping_date
                else
                  default_ship_date
                end

    post_data = {
      'orderId' => label_data['orderId'],
      'carrierCode' => label_data['carrierCode'],
      'serviceCode' => label_data['serviceCode'],
      'confirmation' => label_data['confirmation'],
      'packageCode' => label_data['packageCode'],
      'shipDate' => ship_date,
      'shipTo' => { 'street1'=> self.address_1, 'city'=> self.city, 'country'=> self.country, 'name'=> self.firstname + " " + self.lastname, 'postalCode'=> self.postcode, 'state'=> self.state },
      'weight' => { 'value' => label_data['weight']['value'], 'units' => label_data['weight']['units'] }
    }
    post_data['dimensions'] = label_data['dimensions'] if label_data['dimensions'].present? && label_data['dimensions']['units'].present? && label_data['dimensions']['length'].present? && label_data['dimensions']['width'].present? && label_data['dimensions']['height'].present?
    create_label(store.shipstation_rest_credential.id, post_data)
  end

  def check_valid_label_data
    label_data['orderId'].present? && label_data['packageCode'].present? && label_data['weight'].present? && label_data['carrierCode'].present? && label_data['serviceCode'].present? && label_data['confirmation'].present? && label_data['weight']['value'].present? && label_data['weight']['units'].present?
  end

  def create_label(credential_id, post_data)
    begin
      result = { status: true }
      ss_credential = ShipstationRestCredential.find(credential_id)
      ss_client = Groovepacker::ShipstationRuby::Rest::Client.new(ss_credential.api_key, ss_credential.api_secret)
      post_data['shipFrom'] = {'street1'=> ss_credential.street1, 'city'=> ss_credential.city, 'country'=> ss_credential.country, 'name'=> ss_credential.full_name, 'postalCode'=> ss_credential.postcode, 'state'=> ss_credential.state}
      response = ss_client.create_label_for_order(post_data)
      if response['labelData'].present?
        file_name = "SS_Label_#{post_data['orderId']}_#{Time.current.to_i.to_s}.pdf"
        label_data = Base64.decode64(response['labelData'])
        GroovS3.create_pdf(Apartment::Tenant.current, file_name, label_data)
        result[:dimensions] = '4x6'
        label_url = ENV['S3_BASE_URL'] + '/' + Apartment::Tenant.current + '/pdf/' + file_name
        store_shipping_label_data(post_data['orderId'], label_url, response['shipmentId'])
        result[:url] = label_url
      else
        result[:status] = false
        result[:error_messages] = response.first(3).map { |res| res.join(': ') }.join('<br>')
      end
    rescue StandardError => e
      result[:status] = false
      result[:error_messages] = e.message
    end
    result
  end

  def reset_assigned_tote(user_id)
    addactivity("Order manually cleared from #{ScanPackSetting.last.tote_identifier} #{tote.name}.", User.find_by_id(user_id).try(:name)) if tote
    tote&.update(order_id: nil, pending_order: false)
    reset_scanned_status(User.find_by_id(user_id))
  end

  def order_cup_direct_shipping
    store&.store_type == 'CSV' && store&.order_cup_direct_shipping && Tenant.find_by_name(Apartment::Tenant.current)&.order_cup_direct_shipping
  end

  def print_ss_label?
    return false unless Tenant.find_by_name(Apartment::Tenant.current)&.ss_api_create_label

    store&.store_type === 'Shipstation API 2' && store&.shipstation_rest_credential&.use_api_create_label
  end

  private

  def should_show_carrier(ex_app, carrier_data, carrier_code)
    return true if carrier_code.present? && carrier_data['code'] == carrier_code

    return false if ex_app && !carrier_data['expanded']

    !!carrier_data['visible']
  end

  def store_shipping_label_data(store_order_id, url, shipment_id)
    return if shipment_id == -1

    associated_order = Order.find_by(store_order_id: store_order_id)
    associated_order&.shipping_labels&.create(url: url, shipment_id: shipment_id)
  end
end
