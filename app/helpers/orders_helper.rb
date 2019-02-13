module OrdersHelper
  require 'barby'
  require 'barby/barcode/code_128'
  require 'barby/outputter/png_outputter'

  def import_magento_product(client, session, sku, store_id, import_images, import_products)
    begin
      response = client.call(:catalog_product_info,
                             message: {session: session, productId: sku})
      if response.success?
        @product = response.body[:catalog_product_info_response][:info]


        #add product to the database
        @productdb = Product.new
        @productdb.name = @product[:name]
        @productdb.store_product_id = @product[:product_id]
        @productdb.product_type = @product[:type]
        @productdb.store_id = store_id
        @productdb.weight = @product[:weight].to_f * 16

        # Magento product api does not provide a barcode, so all
        # magento products should be marked with a status new as t
        #they cannot be scanned.
        @productdb.status = 'new'

        @productdbsku = ProductSku.new
        #add productdb sku
        if @product[:sku] != {:"@xsi:type" => "xsd:string"}
          @productdbsku.sku = @product[:sku]
          @productdbsku.purpose = 'primary'

          #publish the sku to the product record
          @productdb.product_skus << @productdbsku
        end

        #get images and categories
        if !@product[:sku].nil? && import_images
          getimages = client.call(:catalog_product_attribute_media_list, message: {session: session,
                                                                                   productId: sku})
          if getimages.success?
            @images = getimages.body[:catalog_product_attribute_media_list_response][:result][:item]
            if !@images.nil?
              if @images.kind_of?(Array)
                @images.each do |image|
                  @productimage = ProductImage.new
                  @productimage.image = image[:url]
                  @productimage.caption = image[:label]
                  @productdb.product_images << @productimage
                end
              else
                @productimage = ProductImage.new
                @productimage.image = @images[:url]
                @productimage.caption = @images[:label]
                @productdb.product_images << @productimage
              end
            end
          end
        end

        if !@product[:categories][:item].nil? &&
          @product[:categories][:item].kind_of?(Array)
          @product[:categories][:item].each do |category_id|
            begin
              get_categories = client.call(:catalog_product_info, message: {session: session,
                                                                            categoryId: category_id})
              if get_categories.success?
                @category = get_categories.body[:catalog_product_info_response][:info]
                @product_cat = ProductCat.new
                @product_cat.category = @category[:name]

                if !@product_cat.category.nil?
                  @productdb.product_cats << @product_cat
                end
              end
            rescue
            end
          end
        end

        #add inventory warehouse
        inv_wh = ProductInventoryWarehouses.new
        inv_wh.inventory_warehouse_id = @store.inventory_warehouse_id
        @productdb.product_inventory_warehousess << inv_wh

        @productdb.save
        @productdb.set_product_status
        @productdb.id
      end
    rescue Exception => e
    end
  end

  def build_pack_item(name, product_type, images, sku, qty_remaining,
                      scanned_qty, packing_placement,
                      barcodes, product_id, order_item_id, child_items, instruction, confirmation, skippable, record_serial,
                      box_id, kit_product_id , updated_at)

    unscanned_item = Hash.new
    unscanned_item["name"] = name
    unscanned_item["instruction"] = instruction
    unscanned_item["confirmation"] = confirmation
    unscanned_item["images"] = images
    unscanned_item["sku"] = sku
    unscanned_item["packing_placement"] = packing_placement
    unscanned_item["barcodes"] = barcodes
    unscanned_item["product_id"] = product_id
    unscanned_item["skippable"] = skippable
    unscanned_item["record_serial"] = record_serial
    unscanned_item["order_item_id"] = order_item_id
    unscanned_item["product_type"] = product_type
    unscanned_item["qty_remaining"] = qty_remaining
    unscanned_item["scanned_qty"] = scanned_qty
    unscanned_item["box_id"] = box_id
    unscanned_item["kit_product_id"] = kit_product_id
    unscanned_item['updated_at'] = updated_at

    if !child_items.nil?
      unscanned_item['child_items'] = child_items
    end

    return unscanned_item
  end

  def build_order_with_single_item_from_ebay(order, transaction, order_transaction)
    order.status = 'awaiting'
    order.store = @store
    order.increment_id = transaction.shippingDetails.sellingManagerSalesRecordNumber
    order.order_placed_time = transaction.createdDate

    if !transaction.buyer.nil? && !transaction.buyer.buyerInfo.nil? &&
      !transaction.buyer.buyerInfo.shippingAddress.nil?
      order.address_1 = transaction.buyer.buyerInfo.shippingAddress.street1
      order.city = transaction.buyer.buyerInfo.shippingAddress.cityName
      order.state = transaction.buyer.buyerInfo.shippingAddress.stateOrProvince
      order.country = transaction.buyer.buyerInfo.shippingAddress.country
      order.postcode = transaction.buyer.buyerInfo.shippingAddress.postalCode
      #split name separated by a space
      if !transaction.buyer.buyerInfo.shippingAddress.name.nil?
        split_name = transaction.buyer.buyerInfo.shippingAddress.name.split(' ')
        order.lastname = split_name.pop
        order.firstname = split_name.join(' ')
      end
    end

    #single item transaction does not have transaction array
    order_item = OrderItem.new
    order_item.price = transaction.transactionPrice
    order_item.qty = transaction.quantityPurchased
    order_item.row_total = transaction.amountPaid
    order_item.sku = order_transaction.transaction.item.sKU
    #create product if it does not exist already
    order_item.product_id =
      import_ebay_product(order_transaction.transaction.item.itemID,
                          order_transaction.transaction.item.sKU, @eBay, @credential)
    order.order_items << order_item

    order
  end

  def build_order_with_multiple_items_from_ebay(order, order_detail)
    order.status = 'awaiting'
    order.store = @store
    order.increment_id = order_detail.shippingDetails.sellingManagerSalesRecordNumber
    order.order_placed_time = order_detail.createdTime

    if !order_detail.shippingAddress.nil?
      order.address_1 = order_detail.shippingAddress.street1
      order.city = order_detail.shippingAddress.cityName
      order.state = order_detail.shippingAddress.stateOrProvince
      order.country = order_detail.shippingAddress.country
      order.postcode = order_detail.shippingAddress.postalCode
      #split name separated by a space
      if !order_detail.shippingAddress.name.nil?
        split_name = order_detail.shippingAddress.name.split(' ')
        order.lastname = split_name.pop
        order.firstname = split_name.join(' ')
      end
    end

    #multiple order items from transaction array
    order_detail.transactionArray.each do |transaction|
      order_item = OrderItem.new
      order_item.price = transaction.transactionPrice
      order_item.qty = transaction.quantityPurchased
      order_item.row_total = transaction.amountPaid
      order_item.sku = transaction.item.sKU
      #create product if it does not exist already
      order_item.product_id =
        import_ebay_product(transaction.item.itemID,
                            transaction.item.sKU, @eBay, @credential)
      order.order_items << order_item
    end

    order
  end

  def generate_order_barcode(increment_id)
    order_barcode = Barby::Code128B.new(increment_id)
    outputter = Barby::PngOutputter.new(order_barcode)
    outputter.margin = 0
    outputter.xdim = 2
    blob = outputter.to_png #Raw PNG data
    increment_id = increment_id.gsub(/[\#\s+]/, '')
    File.open("#{Rails.root}/public/images/#{increment_id}.png",
              'w') do |f|
      f.write blob
    end
    increment_id
  end

  def init_product_attrs(product, available_inv)
    location_primary = product.primary_warehouse.location_primary rescue ""
    order_item = {'productinfo' => product,
                  'available_inv' => order_item_available_inv(product),
                  'sku' => product.primary_sku,
                  'barcode' => product.primary_barcode,
                  'category' => product.primary_category,
                  'image' => product.base_product.primary_image,
                  'spl_instructions_4_packer' => product.spl_instructions_4_packer,
                  'qty_on_hand' => product.primary_warehouse.quantity_on_hand,
                  'location_primary' => location_primary,
                  'sku' => product.primary_sku,
                  'barcode' => product.primary_barcode,
                  'category' => product.primary_category,
                  'image' => product.base_product.primary_image,
                  'spl_instructions_4_packer' => product.spl_instructions_4_packer,
                  'qty_on_hand' => product.primary_warehouse.quantity_on_hand
                 }
  end

  def make_orders_list(orders)
    @orders_result = []

    orders_scanning_count = Order.multiple_orders_scanning_count(orders)

    orders.each do |order|
      itemslength = orders_scanning_count[order.id].values.sum rescue 0
      generate_order_hash(order, itemslength)
    end
    return @orders_result
  end

  def generate_order_hash(order, itemslength)
  	if order.store != nil
      store_name = order.store.name
    else
      store_name = ""
    end
    @orders_result.push({ 'id' => order.id,
                          'store_name' => store_name,
                          'notes' => order.notes_internal,
                          'ordernum' => order.increment_id,
                          'order_date' => order.order_placed_time,
                          'itemslength' => itemslength,
                          'status' => order.status,
                          'recipient' => "#{order.firstname} #{order.lastname}",
                          'email' => order.email,
                          'tracking_num' => order.tracking_num,
                          'city' => order.city,
                          'state' => order.state,
                          'postcode' => order.postcode,
                          'country' => order.country,
                          'tags' => order.order_tags,
                          'custom_field_one' => order.custom_field_one,
                          'custom_field_two' => order.custom_field_two,
                          'store_order_id' => order.store_order_id
                        })
  end

  def avg_time_per_item(username)
    user = User.where('username = ?', username).first

    orders = Order.where('status = ? AND packing_user_id = ? AND scanned_on > ?', 'scanned', user.id, DateTime.now - 30.days)
    tscan_time = 0
    tscan_count = 0
    orders.each do |order|
      tscan_count += order.total_scan_count
      tscan_time += order.total_scan_time
    end
    (tscan_time == 0 || tscan_count == 0) ? nil : tscan_time/tscan_count
  end

  def sort_order params, orders
    begin
      orders = orders.order("#{params[:sort]} #{params[:order]}")
    rescue 
      orders
    end  
    return orders
  end
end
