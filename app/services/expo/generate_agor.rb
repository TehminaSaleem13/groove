# frozen_string_literal: true

module Expo
  class GenerateAgor
    def initialize(order_data)
      @order_data = order_data
      @db_order = Order.find(@order_data['id'])
    end

    def format_data
      order = []
      @order_info = @order_data[:order_info]
      @scan_hash = @order_data[:scan_hash]
      @order = @scan_hash[:data][:order]
      @unscanned_items = @order[:unscanned_items]
      @scanned_items = @order[:scanned_items]
      @multi_shipments = @order[:multi_shipments]
      @activities = @order[:activities]

      new_order = filter_order_data
      new_order[:unscanned_items] = filter_unscanned_items
      new_order[:scanned_items] = filter_scanned_items

      @order_data[:order_info] = filter_order_info
      @order_data[:scan_hash][:data][:order] = new_order
      # Additional Settings
      tote = @db_order.tote
      @order_data[:tote] = tote.pending_order ? tote.name + '-PENDING' : tote.name if tote
      @order_data[:shipment_id] = @db_order.shipment_id
      @order_data[:store_type] = @db_order.store&.store_type
      @order_data[:store_id] = @db_order.store&.id
      @order_data[:popup_shipping_label] = @db_order.store.shipping_easy_credential.popup_shipping_label if @order_data[:store_type] == 'ShippingEasy'
      @order_data[:large_popup] = @db_order.store.shipping_easy_credential.large_popup if @order_data[:store_type] == 'ShippingEasy'
      @order_data[:order_cup_direct_shipping] = @db_order.order_cup_direct_shipping
      @order_data[:multiple_lines_per_sku_accepted] = @db_order.store.shipping_easy_credential.multiple_lines_per_sku_accepted if @order_data[:store_type] == 'ShippingEasy'
      @order_data[:use_api_create_label] = @db_order.store.shipstation_rest_credential.use_api_create_label if @order_data[:store_type] == 'Shipstation API 2' && @db_order.store.shipstation_rest_credential.present?
      @order_data[:auto_click_create_label] = @db_order.store.shipstation_rest_credential.auto_click_create_label if @order_data[:store_type] == 'Shipstation API 2' && @db_order.store.shipstation_rest_credential.present?
      @order_data[:print_ss_label] = @db_order.print_ss_label?
      @order_data
    end

    def filter_order_data
      @order.slice('id', 'increment_id', 'order_placed_time', 'created_at', 'updated_at', 'customer_comments', 'notes_internal', 'notes_toPacker', 'notes_fromPacker', 'status', 'tracking_num', 'packing_user_id', 'notes_from_buyer', 'note_confirmation', 'custom_field_one', 'custom_field_two', 'tags', :unscanned_items, :scanned_items, :multi_shipments, :activities)
    end

    def filter_order_info
      @order_info.slice('id', 'store_name', 'notes', 'ordernum', 'order_date', 'itemslength', 'status', 'tracking_num', 'custom_field_one', 'custom_field_two', 'tags','recipient', 'country', 'city', 'email', 'last_modified','assigned_user_id')
    end

    def filter_scanned_items
      scanned_items = []
      @scanned_items.each do |item|
        barcodes = {}
        images = {}
        scanned_items << item.slice('name', 'instruction', 'confirmation', 'images', 'sku', 'packing_placement', 'barcodes', 'product_id', 'location', 'location2', 'location3', 'skippable', 'record_serial', 'second_record_serial', 'click_scan_enabled', 'type_scan_enabled', 'order_item_id', 'custom_product_1', 'custom_product_2', 'custom_product_3', 'custom_product_display_1', 'custom_product_display_2', 'custom_product_display_3', 'partially_scanned', 'updated_at', 'product_type', 'qty_remaining', 'total_qty', 'scanned_qty', 'child_items')
        scanned_items.last['images'] = item['images'].map(&:as_json).collect { |img| img.slice('id', 'product_id', 'image', 'created_at', 'updated_at') }
        scanned_items.last['barcodes'] = item['barcodes'].map(&:as_json).collect { |barcode| barcode.slice('id', 'product_id', 'barcode', 'created_at', 'updated_at', 'packing_count', 'is_multipack_barcode') }

        scanned_child_items = []
        item['child_items']&.each do |child_item|
          scanned_child_items << child_item.slice('name', 'instruction', 'confirmation', 'images', 'sku', 'barcodes', 'product_id', 'location', 'location2', 'location3', 'skippable', 'record_serial', 'second_record_serial', 'click_scan_enabled', 'type_scan_enabled', 'order_item_id', 'custom_product_1', 'custom_product_2', 'custom_product_3', 'custom_product_display_1', 'custom_product_display_2', 'custom_product_display_3', 'partially_scanned', 'updated_at', 'product_type', 'qty_remaining', 'total_qty', 'scanned_qty')
          scanned_child_items.last['images'] = child_item['images'].map(&:as_json).collect { |img| img.slice('id', 'product_id', 'image', 'created_at', 'updated_at') }
          scanned_child_items.last['barcodes'] = child_item['barcodes'].map(&:as_json).collect { |img| img.slice('id', 'product_id', 'barcode', 'created_at', 'updated_at', 'packing_count', 'is_multipack_barcode') }
        end
        scanned_items.last['child_items'] = scanned_child_items
      end
      scanned_items
    end

    def filter_unscanned_items
      unscanned_items = []
      @unscanned_items.each do |item|
        unscanned_items << item.slice('name', 'instruction', 'confirmation', 'images', 'sku', 'packing_placement', 'barcodes', 'product_id', 'location', 'location2', 'location3', 'skippable', 'record_serial', 'second_record_serial', 'click_scan_enabled', 'type_scan_enabled', 'order_item_id', 'custom_product_1', 'custom_product_2', 'custom_product_3', 'custom_product_display_1', 'custom_product_display_2', 'custom_product_display_3', 'partially_scanned', 'updated_at', 'product_type', 'qty_remaining', 'total_qty', 'scanned_qty', 'child_items')
        unscanned_items.last['images'] = item['images'].map(&:as_json).collect { |img| img.slice('id', 'product_id', 'image', 'created_at', 'updated_at') }
        unscanned_items.last['barcodes'] = item['barcodes'].map(&:as_json).collect { |barcode| barcode.slice('id', 'product_id', 'barcode', 'created_at', 'updated_at', 'packing_count', 'is_multipack_barcode') }

        unscanned_child_items = []
        item['child_items']&.each do |child_item|
          unscanned_child_items << child_item.slice('name', 'instruction', 'confirmation', 'images', 'sku', 'barcodes', 'product_id', 'location', 'location2', 'location3', 'skippable', 'record_serial', 'second_record_serial', 'click_scan_enabled', 'type_scan_enabled', 'order_item_id', 'custom_product_1', 'custom_product_2', 'custom_product_3', 'custom_product_display_1', 'custom_product_display_2', 'custom_product_display_3', 'partially_scanned', 'updated_at', 'product_type', 'qty_remaining', 'total_qty', 'scanned_qty')
          unscanned_child_items.last['images'] = child_item['images'].map(&:as_json).collect { |img| img.slice('id', 'product_id', 'image', 'created_at', 'updated_at') }
          unscanned_child_items.last['barcodes'] = child_item['barcodes'].map(&:as_json).collect { |img| img.slice('id', 'product_id', 'barcode', 'created_at', 'updated_at', 'packing_count', 'is_multipack_barcode') }
        end
        unscanned_items.last['child_items'] = unscanned_child_items
      end
      unscanned_items
    end
  end
end
