module ProductsService
  class GenerateCSV < ProductsService::Base
    attr_accessor :products, :csv, :bulk_actions_id, :headers, :default_inv_id

    def initialize(*args)
      @products, @csv, @bulk_actions_id, @bulk_csv = args
      @headers = []
      @data_mapping = {}
      @default_inv_id = InventoryWarehouse.where(is_default: true).first.id
      preload_associations(products)
    end

    def call
      bulk_action?
      set_header
      set_data_mapping

      if @bulk_csv
        @csv << headers
        products.each do |item|
          if @bulk_action
            @bulk_action.reload
            return true if bulk_action_cancelled?
          end
          @csv << process_data(item)
        end
        @csv
      else
        @csv = CSV.generate(headers: true) do |csv|
          csv << headers.to_a
          products.each do |item|
            if @bulk_action
              @bulk_action.reload
              return true if bulk_action_cancelled?
            end
            csv << process_data(item)
          end
        end
        @csv
      end

      # if @bulk_csv
      #   @csv << headers
      #   products.each do |item|
      #     if @bulk_action
      #       @bulk_action.reload
      #       return true if bulk_action_cancelled?
      #     end
      #     @csv << process_data(item)
      #   end
      #   @csv
      # else
      #   csv << headers.join(",")
      #   csv << "\n"
      #   products.each do |item|
      #     if @bulk_action
      #       @bulk_action.reload
      #       return true if bulk_action_cancelled?
      #     end
      #     arr = process_data(item)
      #     new_arr = []
      #     arr.each do |val|
      #       new_arr << (val.class==String ? "\"#{val}\"" : val)
      #     end
      #     csv << new_arr.join(",")
      #     csv << "\n"
      #   end
      #   csv
      # end

      # if @bulk_csv
      #   @csv << headers
      #   products.each do |item|
      #     if @bulk_action
      #       @bulk_action.reload
      #       return true if bulk_action_cancelled?
      #     end
      #     @csv << process_data(item)
      #   end
      #   @csv
      # else
      #   csv << headers.join(",")
      #   csv << "\n"
      #   products.each do |item|
      #     if @bulk_action
      #       @bulk_action.reload
      #       return true if bulk_action_cancelled?
      #     end
      #     arr = process_data(item)
      #     new_arr = []
      #     arr.each do |val|
      #       new_arr << (val.class==String ? "\"#{val}\"" : val)
      #     end
      #     csv << new_arr.join(",")
      #     csv << "\n"
      #   end
      #   csv
      # end
    end

    private

    def bulk_action?
      return unless bulk_actions_id
      @bulk_action = GrooveBulkActions.find(bulk_actions_id)
    end

    def set_header
      @headers = [
        'ID', 'Product Name', 'SKU 1', 'SKU 2', 'SKU 3', 'SKU 4', 'SKU 5', 'SKU 6', 'Barcode 1','Barcode 1 Qty', 'Barcode 2', 'Barcode 2 Qty', 'Barcode 3', 'Barcode 3 Qty', 'Barcode 4', 'Barcode 4 Qty', 'Barcode 5', 'Barcode 5 Qty', 'Barcode 6', 'Barcode 6 Qty', 'Location 1', 'Location 1 Qty', 'Location 2', 'Location 2 Qty', 'Location 3', 'Location 3 Qty', 'Location 4', 'Location 4 Qty', 'Qty On Hand','Absolute Image URL', 'Packing Instructions', 'Packing Instructions Conf', 'Product Receiving Instructions', 'Categories', 'FNSKU', 'ASIN', 'FBA-UPC', 'ISBN', 'EAN', 'Supplier SKU', 'AVG Cost', 'Count Group', 'Restock Lead Time', 'Product Scanning Sequence', 'Custom Product 1', 'Custom Product Display 1', 'Custom Product 2', 'Custom Product Display 2', 'Custom Product 3', 'Custom Product Display 3', 'Opt. Click Scan', 'Opt. Type-in Count', 'Opt. Intangible', 'Opt. Add to Any Order', 'Opt. Skippable', 'Opt. Record Serial 1', 'Opt. Record Serial 2', 'Store ID', 'Status', 'Created At', 'Updated At'
      ]
    end

    def filter_and_arrange_fields(all_product_fields)
      delete_list = ['store_product_id', 'product_type', 'pack_time_adj', 'kit_parsing', 'is_kit', 'disable_conf_req', 'total_avail_ext', 'shipping_weight', 'status_updated', 'is_inventory_product']
      delete_list.each do |del|
        all_product_fields.delete_at(all_product_fields.index(del)) if all_product_fields.index(del)
      end
      insert_list = ['store_id', 'status', 'created_at', 'updated_at']
      insert_list.each do |ins|
        all_product_fields.insert(-1, all_product_fields.delete(ins))
      end
      all_product_fields
    end

    def process_data(item)
      data = []
      inventory_wh = find_inventory_wh(item)
      item_mapping = @data_mapping['item']
      inventory_wh_mapping = @data_mapping['inventory_wh']
      item_other_skus_barcodes = @data_mapping['item_other_skus_barcodes']
      item_categories = @data_mapping['item_categories']
      headers.each do |title|
        data.push(
          find_value([
                       item, inventory_wh, title, item_mapping, inventory_wh_mapping,
                       item_other_skus_barcodes, item_categories
                     ])
        )
      end
      do_if_bulk_action
      data
    end

    def set_data_mapping
      @data_mapping = {
        'item' => {
          'ID' => 'id',
          'Product Name' => 'name',
          'SKU 1' => 'primary_sku',
          'Barcode 1' => 'primary_barcode',
          'Barcode 1 Qty' => 'primary_barcode_qty',
          'Absolute Image URL' => 'primary_image',
          'Packing Instructions' => 'packing_instructions',
          'Packing Instructions Conf' => 'packing_instructions_conf',
          'Product Receiving Instructions' => 'product_receiving_instructions',
          'Packing Placement' => 'packing_placement',
          'Custom Product 1' => 'custom_product_1',
          'Custom Product Display 1' => 'custom_product_display_1',
          'Custom Product 2' => 'custom_product_2',
          'Custom Product Display 2' => 'custom_product_display_2',
          'Custom Product 3' => 'custom_product_3',
          'Custom Product Display 3' => 'custom_product_display_3',
          'FNSKU' => 'fnsku',
          'ASIN' => 'asin',
          'FBA-UPC' => 'fba_upc',
          'ISBN' => 'isbn',
          'EAN' => 'ean',
          'Supplier SKU' => 'supplier_sku',
          'AVG Cost' => 'avg_cost',
          'Count Group' => 'count_group',
          'Opt. Click Scan' => 'click_scan_enabled',
          'Opt. Type-in Count' => 'type_scan_enabled',
          'Opt. Intangible' => 'is_intangible',
          'Opt. Add to Any Order' => 'add_to_any_order',
          'Opt. Skippable' => 'is_skippable',
          'Opt. Record Serial 1' => 'record_serial',
          'Opt. Record Serial 2' => 'second_record_serial',
          'Restock Lead Time' => 'restock_lead_time',
          'Store ID' => 'store_id',
          'Status' => 'status',
          'Created At' => 'created_at',
          'Updated At' => 'updated_at'
        },
        'item_other_skus_barcodes' => {
          'SKU 2' => 'sku',
          'SKU 3' => 'sku',
          'SKU 4' => 'sku',
          'SKU 5' => 'sku',
          'SKU 6' => 'sku',
          'Barcode 2' => 'barcode',
          'Barcode 2 Qty' => 'packing_count',
          'Barcode 3' => 'barcode',
          'Barcode 3 Qty' => 'packing_count',
          'Barcode 4' => 'barcode',
          'Barcode 4 Qty' => 'packing_count',
          'Barcode 5' => 'barcode',
          'Barcode 5 Qty' => 'packing_count',
          'Barcode 6' => 'barcode',
          'Barcode 6 Qty' => 'packing_count'
        },
        'item_categories' => {
          'Categories' => 'categories'
        },
        'inventory_wh' => {
          'Location 1' => 'location_primary',
          'Qty On Hand' => 'quantity_on_hand',
          'Location 2' => 'location_secondary',
          'Location 3' => 'location_tertiary',
          'Location 4' => 'location_quaternary',
          'Location 1 Qty' => 'location_primary_qty',
          'Location 2 Qty' => 'location_secondary_qty',
          'Location 3 Qty' => 'location_tertiary_qty',
          'Location 4 Qty' => 'location_quaternary_qty',
        }
      }
    end

    def find_value(parameters)
      item, inventory_wh, title, item_mapping, inventory_wh_mapping,
      item_other_skus_barcodes, item_categories = parameters

      if this_in_that(title, item_mapping)
        value_for(item, item_mapping[title])
      elsif this_in_that(title, inventory_wh_mapping)
        value_for(inventory_wh, inventory_wh_mapping[title])
      elsif this_in_that(title, item_other_skus_barcodes)
        attribute = item_other_skus_barcodes[title]
        find_other_skus_barcodes(item, title, attribute)
      elsif this_in_that(title, item_categories)
        item.product_cats.map(&:category).join(', ')
      else
        item.attributes.values_at(title).try(:first)
      end
    end

    def value_for(obj, method)
      obj.send(method)
    end

    def this_in_that(title, mapping)
      title.in? mapping.keys
    end

    def find_inventory_wh(item)
      item.product_inventory_warehousess.find do |inv|
        inv.inventory_warehouse_id.eql?(default_inv_id)
      end
    end

    def find_other_skus_barcodes(item, title, attribute)
      begin
        collection = attribute == "packing_count" ? item.send("product_barcodes") : item.send("product_#{attribute}s")
        index = title.gsub(/[^\d]/, '').to_i
        collection.length > 1 ? collection[index - 1].send(attribute) : ''
      rescue
      end
    end

    def do_if_bulk_action
      return unless @bulk_action
      @bulk_action.completed += 1
      @bulk_action.save
    end

    def bulk_action_cancelled?
      result = false
      if @bulk_action.cancel == true
        @bulk_action.status = 'cancelled'
        @bulk_action.save
        result = true
      end
      result
    end
  end
end
