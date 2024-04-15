# frozen_string_literal: true

module Groovepacker
  module Orders
    class Export < Groovepacker::Orders::Base
      def order_items_export(tenant_name, selected_orders, username = nil)
        Apartment::Tenant.switch!(tenant_name)
        @general_settings = GeneralSetting.all.first
        @current_workflow = Tenant.find_by_name(Apartment::Tenant.current).try(:scan_pack_workflow)
        if @general_settings.export_items == 'disabled'
          set_status_and_message(false, 'Order export items is disabled.', ['push'])
          return @result
        end

        @request = selected_orders.class == Array ? true : false
        @username = username
        @selected_orders = @request ? search_orders_by_ids(selected_orders) : selected_orders
        @items_list = {}
        @increment = 0
        @filename = get_filename

        add_order_items_in_items_list
        generate_csv_file

        @result
      end

      private

      def search_orders_by_ids(ids)
        Order.where('id IN (?)', ids)
      end

      def add_order_items_in_items_list
        @selected_orders.each do |order|
          @inv_warehouse_id = InventoryWarehouse.where(is_default: 1).first.id
          unless order.store.nil? || order.store.inventory_warehouse.nil?
            @inv_warehouse_id = order.store.inventory_warehouse_id
          end

          order.order_items.each do |single_item|
            add_single_item_in_items_list(order, single_item) unless single_item.product.nil?
          end
        end
      end

      def add_single_item_in_items_list(order, single_item)
        product = single_item.product
        if product.is_kit == 0 || %w[single depends].include?(product.kit_parsing)
          add_item_in_items_list(order, single_item, product, 'order_item')
        end

        if product.is_kit == 1 && %w[individual depends].include?(product.kit_parsing)
          single_item.order_item_kit_products.each do |kit_item|
            item = ProductKitSkus.find(kit_item.product_kit_skus_id)
            add_item_in_items_list(order, single_item, item, 'kit_item', kit_item)
          end
        end
      end

      def add_item_in_items_list(order, single_item, item, type, kit_item = nil)
        @product = type == 'kit_item' ? item.option_product : item
        @item_quantity = type == 'kit_item' ? item.qty * single_item.qty : single_item.qty

        product_sku = @product.product_skus.order('product_skus.order ASC').first
        return if product_sku.nil?

        create_single_row(order, product_sku, single_item, type, kit_item)
      end

      def create_single_row(order, product_sku, single_item, type, kit_item = nil)
        if @items_list.key?(product_sku.sku) && @general_settings.export_items == 'by_sku'
          @items_list[product_sku.sku][:quantity] = @items_list[product_sku.sku][:quantity] + @item_quantity
        else
          single_row_list = @general_settings.export_items == 'standard_order_export' ? fetch_standard_single_row(order, product_sku, single_item, type, kit_item) : fetch_single_row(order, product_sku)
          push_item_row(single_row_list, product_sku)
        end
      end

      def fetch_single_row(order, product_sku)
        product_barcodes = @product.product_barcodes.order('product_barcodes.order ASC')
        single_row_list = row_map.dup
        single_row_list = single_row_list.merge(quantity: @item_quantity,
                                                product_name: @product.name,
                                                primary_sku: product_sku.sku,
                                                product_status: @product.status,
                                                order_number: order.increment_id)

        single_row_list = add_barcode_info(single_row_list, product_barcodes)
        single_row_list = add_inv_warehouse_info(single_row_list)
        single_row_list[:image_url] = begin
                                          @product.primary_image
                                      rescue StandardError
                                        nil
                                        end
        single_row_list
      end

      def fetch_standard_single_row(order, product_sku, single_item, type, kit_item = nil)
        product_barcodes = @product.product_barcodes.order('product_barcodes.order ASC')
        scanned_count = type == 'kit_item' ? kit_item.scanned_qty : single_item.scanned_qty
        single_row_list = order_export_row_map.dup
        single_row_list = single_row_list.merge(
          order_number: order.increment_id,
          store_name: order.store.name,
          order_date_time: order.order_placed_time.strftime('%Y-%m-%d %H:%M:%S'),
          sku: product_sku.sku,
          product_name: @product.name,
          barcode: product_barcodes[0].try(:barcode),
          qty: @item_quantity,
          first_name: order.firstname,
          last_name: order.lastname,
          email: order.email,
          address_1: order.address_1,
          address_2: order.address_2,
          city: order.city,
          state: order.state,
          postal_code: order.postcode,
          country: order.country,
          customer_comments: order.customer_comments,
          tags: order.tags,
          internal_notes: order.notes_internal,
          tracking_num: order.tracking_num,
          scanned_count: scanned_count,
          unscanned_count: single_item.qty - scanned_count,
          removed_count: type == 'kit_item' ? 0 : single_item.removed_qty
        )

        if @current_workflow == 'product_first_scan_to_put_wall'
          single_row_list = single_row_list.merge(
            order_num: order.increment_id,
            sku: product_sku.sku,
            tote: order.tote.try(:name) || 'NA',
            qty_remaining: single_item.scanned_status == 'scanned' ? 0 : single_item.qty - single_item.scanned_qty,
            qty_in_tote: order.tote.try(:name) ? single_item.scanned_qty : 0,
            qty_ordered: single_item.qty
          )
        end

        single_row_list = single_row_list.merge(@general_settings.custom_field_one.parameterize.underscore.to_sym => order.custom_field_one) if @general_settings.custom_field_one
        single_row_list = single_row_list.merge(@general_settings.custom_field_two.parameterize.underscore.to_sym => order.custom_field_two) if @general_settings.custom_field_two
        single_row_list
      end

      def add_barcode_info(single_row_list, product_barcodes)
        return single_row_list if product_barcodes.empty?

        single_row_list[:primary_barcode] = product_barcodes[0].barcode
        if product_barcodes.length == 2
          single_row_list[:secondary_barcode] = product_barcodes[1].barcode
        elsif product_barcodes.length == 3
          single_row_list[:tertiary_barcode] = product_barcodes[2].barcode
        elsif  product_barcodes.length == 4
          single_row_list[:quaternary_barcode] = product_barcodes[3].barcode
        elsif  product_barcodes.length == 5
          single_row_list[:quinary_barcode] = product_barcodes[4].barcode
        elsif  product_barcodes.length == 6
          single_row_list[:senary_barcode] = product_barcodes[5].barcode
        end
        single_row_list
      end

      def add_inv_warehouse_info(single_row_list)
        product_inventory_warehouse = @product.get_inventory_warehouse_info(@inv_warehouse_id)
        return single_row_list if product_inventory_warehouse.nil?

        single_row_list[:location_primary] = product_inventory_warehouse.location_primary
        single_row_list[:location_secondary] = product_inventory_warehouse.location_secondary
        single_row_list[:location_tertiary] = product_inventory_warehouse.location_tertiary
        single_row_list[:available_inventory] = product_inventory_warehouse.available_inv
        single_row_list
      end

      def push_item_row(single_row_list, product_sku)
        if @general_settings.export_items == 'by_sku'
          @items_list[product_sku.sku] = single_row_list
        else
          @items_list[@increment] = single_row_list
          @increment += 1
        end
      end

      # This mentod will generate CSV file and return the filename as S3 URL generated in get_csv_export method.
      def generate_csv_file
        export_rom_map = @general_settings.export_items == 'standard_order_export' ? order_export_row_map : row_map
        csv = CSV.generate(headers: true) do |csv|
          csv << export_rom_map.keys
          @items_list.values.each do |line|
            item_csv = []
            line.values.each_with_index do |row, _index|
              item_csv << row
            end
            csv << item_csv
          end
        end
        # csv = ""
        # header = "#{row_map.keys[0]}"
        # row_map.keys.each_with_index do |header_row, index|
        #   header << "," + "#{row_map.keys[index]}" if index != 0
        # end
        # header << "\n"
        # csv << header
        # @items_list.values.each do |line|
        #   new_row = "#{line.values[0].to_s}, "
        #   line.values.each_with_index do |row, index|
        #     new_row << "#{row}, " if index != 0
        #   end
        #   new_row << "\n"
        #   csv << new_row
        # end
        if @request
          generate_url = GroovS3.create_export_csv(Apartment::Tenant.current, @filename, csv).url.gsub('http:', 'https:')
          g = GenerateBarcode.new(url: generate_url, status: 'completed', print_type: 'bulk_order_items')
          g.user_id = begin
                        User.where(username: @username).first.id
                      rescue StandardError
                        nil
                      end
          g.save
        else
          @result['filename'] = GroovS3.create_export_csv(Apartment::Tenant.current, @filename, csv).url.gsub('http:', 'https:')
        end
      end
    end
  end
end
