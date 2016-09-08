module Groovepacker
  module Orders
    class Export < Groovepacker::Orders::Base

      def order_items_export(selected_orders)
        @general_settings = GeneralSetting.all.first
        if @general_settings.export_items == 'disabled'
          set_status_and_message(false, 'Order export items is disabled.', ['push'])
          return @result
        end

        @selected_orders, @items_list = selected_orders, {}
        @increment, @filename = 0, get_filename

        add_order_items_in_items_list
        generate_csv_file
        
        return @result
      end

      private
        def add_order_items_in_items_list
          @selected_orders.each do |order|
            @inv_warehouse_id = InventoryWarehouse.where(:is_default => 1).first.id
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
          if product.is_kit == 0 || ['single', 'depends'].include?(product.kit_parsing)
            add_item_in_items_list(order, single_item, product)
          end

          if product.is_kit == 1 && ['individual', 'depends'].include?(product.kit_parsing)
            product.product_kit_skuss.each do |kit_item|
              add_item_in_items_list(order, single_item, kit_item, "kit_item")
            end
          end
        end

        def add_item_in_items_list(order, single_item, item, type=nil)
          @product = type=="kit_item" ? item.option_product : item
          @item_quantity = type=="kit_item" ? item.qty*single_item.qty : single_item.qty

          product_sku = @product.product_skus.order("product_skus.order ASC").first
          return if product_sku.nil?
          create_single_row(order, product_sku)
        end

        def create_single_row(order, product_sku)
          if @items_list.has_key?(product_sku.sku) && @general_settings.export_items == 'by_sku'
            @items_list[product_sku.sku][:quantity] = @items_list[product_sku.sku][:quantity] + @item_quantity
          else
            single_row_list = fetch_single_row(order, product_sku)
            push_item_row(single_row_list, product_sku)
          end
        end

        def fetch_single_row(order, product_sku)
          product_barcodes = @product.product_barcodes.order("product_barcodes.order ASC")
          single_row_list = row_map.dup
          single_row_list = single_row_list.merge({ :quantity => @item_quantity,
                                                    :product_name => @product.name,
                                                    :primary_sku => product_sku.sku,
                                                    :product_status => @product.status,
                                                    :order_number => order.increment_id })
          
          single_row_list = add_barcode_info(single_row_list, product_barcodes)
          single_row_list = add_inv_warehouse_info(single_row_list)
          single_row_list[:image_url] = @product.primary_image rescue nil
          single_row_list
        end

        def add_barcode_info(single_row_list, product_barcodes)
          return single_row_list if product_barcodes.length == 0
          single_row_list[:primary_barcode] = product_barcodes[0].barcode

          if product_barcodes.length == 2
            single_row_list[:secondary_barcode] = product_barcodes[1].barcode
          elsif product_barcodes.length >= 3
            single_row_list[:tertiary_barcode] = product_barcodes[2].barcode
          end
          single_row_list
        end

        def add_inv_warehouse_info(single_row_list)
          product_inventory_warehouse = @product.get_inventory_warehouse_info(@inv_warehouse_id)
          return single_row_list if product_inventory_warehouse.nil?
          single_row_list[:location_primary] = product_inventory_warehouse.location_primary
          single_row_list[:location_secondary] = product_inventory_warehouse.location_secondary
          single_row_list[:location_tertiary] = product_inventory_warehouse.location_tertiary
          single_row_list[:available_inventory]=product_inventory_warehouse.available_inv
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

        def generate_csv_file
          csv = ""
          header = "#{row_map.keys[0]}"
          row_map.keys.each_with_index do |header_row, index|
            header << "," + "#{row_map.keys[index]}" if index != 0
          end
          header << "\n"
          csv << header
          @items_list.values.each do |line|
            new_row = "#{line.values[0].to_s}, "
            line.values.each_with_index do |row, index|
              new_row << "#{row}, " if index != 0
            end
            new_row << "\n"
            csv << new_row
          end
          @result['filename'] = GroovS3.create_export_csv(Apartment::Tenant.current, @filename, csv).url
        end
    end
  end
end
