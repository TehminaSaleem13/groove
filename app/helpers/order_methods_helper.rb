module OrderMethodsHelper
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
    product_barcode = ProductBarcode.where(:barcode => barcode)

    product_barcode = product_barcode.length > 0 ? product_barcode.first : nil

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
    chek_for_recently_scanned(limited_order_items, most_recent_scanned_product) if most_recent_scanned_product
    update_unscanned_list(limited_order_items, unscanned_list)

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
    boxes = Box.where(order_id: self.id)
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
end
