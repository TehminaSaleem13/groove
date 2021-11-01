module OrderMethodsHelper
  include ActionView::Helpers::NumberHelper

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

    shipments = Order.where(store_order_id: source_order_ids.split(',').map(&:to_i)) if source_order_ids.present? unless se_old_split_shipments
    se_old_combined_shipments = (shipments.try(:any?) && !se_old_split_shipments) ? true : false

    if se_old_split_shipments || se_old_combined_shipments
      shipments.each do |shipment|
        if shipment.status == 'scanned'
          current_status = "Imported #{shipment.created_at.strftime('%B %e %Y %l:%M %p')} - Scanned #{shipment.scanned_on.strftime('%B %e %Y %l:%M %p')}"
        else
          shipment_status = (shipment.scanning_count[:scanned].to_i > 0 ? 'Partial Scanned' : 'Unscanned') rescue 'Unscanned'
          current_status = "Imported #{shipment.created_at.strftime('%B %e %Y %l:%M %p')} - #{shipment_status}"
        end
        se_old_shipments << { id: shipment.id, increment_id: shipment.increment_id, status: current_status }
      end
      result_order['se_old_split_shipments'] = se_old_split_shipments ? se_old_shipments : nil
      result_order['se_old_combined_shipments'] = se_old_combined_shipments ? se_old_shipments : nil
    else
      all_shipments = { shipments: [] }
      shipments = Order.includes(:order_items).where('orders.prime_order_id = ? AND orders.status != ? AND split_from_order_id != ? AND (cloned_from_shipment_id IS NULL OR cloned_from_shipment_id = ?)', prime_order_id, 'scanned', '', '') if prime_order_id.present? && Order.where('split_from_order_id != ? AND (cloned_from_shipment_id IS NULL OR cloned_from_shipment_id = ?)', '', '').where(prime_order_id: prime_order_id).count > 1
      return result_order if shipments.blank? || shipments.count == 1

      all_shipments[:present] = true
      shipments.each do |shipment|
        items_count = shipment.get_items_count
        all_shipments[:shipments] << { id: shipment.id, increment_id: shipment.increment_id, items_count: items_count }
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
    self.order_items.each do |order_item|
      product = order_item.product
      product_kit_skuss = product.product_kit_skuss
      next if product.blank?
      is_new_or_inactive = product.status.eql?('new') || product.status.eql?('inactive')
      if is_new_or_inactive || (order_item.qty.eql?(0) && order_item.skipped_qty.eql?(0)) || product_kit_skuss.map(&:qty).index(0)
        products_list << product.as_json(
          include: {
            product_images: {
              only: [:image]
            }
          }
        ).merge(sku: product.primary_sku, barcode: product.primary_barcode)
        products_list = check_and_add_inactive_kit_items(products_list, product_kit_skuss)
      end
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

    #check if barcode is present in a kit which has kitparsing of depends
    if product_barcodes.any?
      self.order_items.includes(:product).each do |order_item|
        if order_item.product.is_kit == 1 && order_item.product.kit_parsing == 'depends' &&
          order_item.scanned_status != 'scanned'
          order_item.product.product_kit_skuss.each do |kit_product|
            if kit_product.option_product_id.in? product_barcodes.pluck(:product_id)
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

  def get_unscanned_items(
    most_recent_scanned_product: nil, barcode: nil,
    order_item_status:['unscanned', 'notscanned', 'partially_scanned'],
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

    unscanned_list = unscanned_list.sort do |a, b|
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
    ScanPackSetting.last.scanning_sequence == "kits_sequence" ? unscanned_list.sort_by { |row| (row["partially_scanned"] ? 0 : 1) } : unscanned_list
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
      update_scanned_list(order_item, scanned_list)
    end

    #transform scanned_list to move all child items into displaying as individual items
    scanned_list.each do |scanned_item|
      if scanned_item['product_type'] == 'individual'
        scanned_item['child_items'].reverse!
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
                                         child_item['box_id'], child_item['kit_product_id'], child_item ['updated_at'])
              scanned_list.push(new_item)
            end
          end
        end
      end
    end
   scanned_list.sort! { |a,b| b["updated_at"] <=> a["updated_at"] }
  end

  def get_boxes_data
    boxes = Box.where(order_id: id)
    order_item_boxes = []
    boxes.each do |box|
      order_item_boxes << box.order_item_boxes
    end

    list = []
    order_item_boxes.flatten.each do |o|
      data1 = {}
      if !o.kit_id.nil?
        order_item_kit_product = OrderItemKitProduct.find(o.kit_id)
        product_kit_sku = order_item_kit_product.product_kit_skus
        product = Product.find(product_kit_sku.option_product_id)
        data1 = { product_name: product.name ,qty:  o.item_qty, box: o.box.id  }
        list << data1
      end
    end
    list = list.group_by { |d| d[:box] }
    result = { box: boxes.as_json(only: [:id, :name]), order_item_boxes: order_item_boxes.flatten, list: list   }
  end

  def ss_label_order_data
    begin
      ss_rest_credential = store.shipstation_rest_credential
      order_ss_label_data = ss_label_data || {}
      direct_print_data = {}
      ss_client = Groovepacker::ShipstationRuby::Rest::Client.new(ss_rest_credential.api_key, ss_rest_credential.api_secret)
      general_settings = GeneralSetting.last
      direct_print_data = try_creating_label if ss_rest_credential.skip_ss_label_confirmation && (!Box.where(order_id: id).many? || general_settings.per_box_shipping_label_creation == 'per_box_shipping_label_creation_none')
      if direct_print_data[:status]
        order_ss_label_data['direct_printed'] = true
        order_ss_label_data['direct_printed_url'] = direct_print_data[:url]
        order_ss_label_data[:dimensions] = '4x6'
        return order_ss_label_data
      end

      order_ss_label_data['order_number'] = increment_id
      order_ss_label_data['credential_id'] = ss_rest_credential.id
      order_ss_label_data['skip_ss_label_confirmation'] = ss_rest_credential.skip_ss_label_confirmation
      order_ss_label_data['orderId'] ||= store_order_id
      order_ss_label_data['available_carriers'] = JSON.parse(ss_client.list_carriers.body) rescue []
      order_ss_label_data['fromPostalCode'] = User.current.try(:warehouse_postcode).present? ? User.current.warehouse_postcode : ss_rest_credential.postcode
      order_ss_label_data['toCountry'] = country
      order_ss_label_data['toState'] = state
      order_ss_label_data['toPostalCode'] = postcode
      order_ss_label_data['toName'] = customer_name
      order_ss_label_data['toAddress1'] = address_1
      order_ss_label_data['toAddress2'] = address_2
      order_ss_label_data['toCity'] = city
      order_ss_label_data['label_shortcuts'] = ss_rest_credential.label_shortcuts
      order_ss_label_data['available_carriers'].each do |carrier|
        carrier['visible'] = !(ss_rest_credential.disabled_carriers.include? carrier['code'])
        next unless carrier['visible']
        data = {
          carrierCode: carrier['code'],
          fromPostalCode: order_ss_label_data['fromPostalCode'],
          toCountry: country,
          toState: state,
          toPostalCode: postcode,
          confirmation: order_ss_label_data['confirmation']
        }
        data = data.merge(weight: order_ss_label_data['weight']) if order_ss_label_data['weight']
        rates_response = ss_client.get_ss_label_rates(data.to_h)
        carrier['errors'] = rates_response.first(3).map { |res| res = res.join(': ')}.join('<br>') unless rates_response.ok?
        next unless rates_response.ok?
        carrier['rates'] = JSON.parse(rates_response.body)
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
        carrier['rates'].map { |r| r['visible'] = !((ss_rest_credential.disabled_rates[carrier['code']].include? r['serviceName']) rescue false) }
        next unless carrier['code'] == 'stamps_com'
        carrier['rates'].each do |rate|
          rate['packageCode'] = carrier['packages'].select { |h| h['name'] == rate['serviceName'].split(' - ').last }.first['code'] rescue nil
        end
      end
      order_ss_label_data
    rescue => e
      puts e
    end
  end

  def try_creating_label
    return { status: false } unless check_valid_label_data
    post_data = {
      "orderId" => ss_label_data['orderId'],
      "carrierCode" => ss_label_data['carrierCode'],
      "serviceCode" => ss_label_data['serviceCode'],
      "confirmation" => ss_label_data['confirmation'],
      "shipDate" => ss_label_data['shipDate'].present? ? Time.zone.parse(ss_label_data['shipDate']).strftime("%a, %d %b %Y") : Time.current.strftime("%a, %d %b %Y"),
      "weight" => { "value"=> ss_label_data['weight']['value'], "units"=> ss_label_data['weight']['units'] }
    }
    post_data.merge!("dimensions" => ss_label_data['dimensions']) if ss_label_data['dimensions'].present? && ss_label_data['dimensions']['units'].present? && ss_label_data['dimensions']['length'].present? && ss_label_data['dimensions']['width'].present? && ss_label_data['dimensions']['height'].present?
    result = create_label(store.shipstation_rest_credential.id, post_data)
  end

  def check_valid_label_data
    ss_label_data['orderId'].present? && ss_label_data['packageCode'].present? && ss_label_data['weight'].present? && ss_label_data['carrierCode'].present? && ss_label_data['serviceCode'].present? && ss_label_data['confirmation'].present? && ss_label_data['weight']['value'].present? && ss_label_data['weight']['units'].present? && ss_label_data['weight']['WeightUnits'].present?
  end

  def create_label(credential_id, post_data)
    begin
      result = { status: true}
      ss_credential = ShipstationRestCredential.find(credential_id)
      ss_client = Groovepacker::ShipstationRuby::Rest::Client.new(ss_credential.api_key, ss_credential.api_secret)
      response = ss_client.create_label_for_order(post_data)
      if response['labelData'].present?
        file_name = "SS_Label_#{post_data['orderId']}.pdf"
        reader_file_path = Rails.root.join('public', 'pdfs', file_name)
        label_data = Base64.decode64(response['labelData'])
        File.open(reader_file_path, 'wb') do |file|
            file.puts label_data
        end
        GroovS3.create_pdf(Apartment::Tenant.current, file_name, File.open(reader_file_path).read)
        result[:dimensions] = '4x6'
        result[:url] = ENV['S3_BASE_URL'] + '/' + Apartment::Tenant.current + '/pdf/' + file_name
      else
        result[:status] = false
        result[:error_messages] = response.first(3).map { |res| res = res.join(': ')}.join('<br>')
      end
    rescue => e
      result[:status] = false
      result[:error_messages] = e.message
    end
    result
  end

  def reset_assigned_tote(user_id)
    addactivity("Order manually cleared from #{ScanPackSetting.last.tote_identifier} #{tote.name}.", User.find_by_id(user_id).try(:name)) if tote
    tote.update_attributes(order_id: nil, pending_order: false) if tote
    reset_scanned_status(User.find_by_id(user_id))
  end
end
