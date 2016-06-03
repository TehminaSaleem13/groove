module ProductsService
  class GenerateCSV < ProductsService::Base
    attr_accessor :products, :csv, :bulk_actions_id, :headers

    def initialize(*args)
      @products, @csv, @bulk_actions_id = args
      @headers = []
      @data_mapping = {}
    end

    def call
      bulk_action?
      set_header
      check_headers_against_product_column
      set_data_mapping
      csv << headers
      products.each do |item|
        if @bulk_action
          @bulk_action.reload
          return true if bulk_action_cancelled?
        end
        csv << process_data(item)
      end
      csv
    end

    private

    def bulk_action?
      return unless bulk_actions_id
      @bulk_action = GrooveBulkActions.find(bulk_actions_id)
    end

    def set_header
      @headers = [
        'ID', 'Name', 'SKU 1', 'Barcode 1', 'BinLocation 1', 'QOH',
        'Primary Image', 'Weight', 'Primary Category',
        'SKU 2', 'SKU 3', 'Barcode 2', 'Barcode 3', 'BinLocation 2',
        'BinLocation 3'
      ]
    end

    def check_headers_against_product_column
      Product.column_names.each do |name|
        next if headers.any? { |s| s.casecmp(name) == 0 }
        headers.push(name)
      end
    end

    def process_data(item)
      data = []
      inventory_wh = find_inventory_wh(item)
      item_mapping = @data_mapping['item']
      inventory_wh_mapping = @data_mapping['inventory_wh']
      item_other_skus_barcodes = @data_mapping['item_other_skus_barcodes']
      headers.each do |title|
        data.push(
          find_value([
            item, inventory_wh, title, item_mapping, inventory_wh_mapping,
            item_other_skus_barcodes
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
          'Name' => 'name',
          'SKU 1' => 'primary_sku',
          'Barcode 1' => 'primary_barcode',
          'Primary Image' => 'primary_image',
          'Weight' => 'weight',
          'Primary Category' => 'primary_category'
        },
        'item_other_skus_barcodes' => {
          'SKU 2' => 'sku',
          'SKU 3' => 'sku',
          'Barcode 2' => 'barcode',
          'Barcode 3' => 'barcode'
        },
        'inventory_wh' => {
          'BinLocation 1' => 'location_primary',
          'QOH' => 'quantity_on_hand',
          'BinLocation 2' => 'location_secondary',
          'BinLocation 3' => 'location_tertiary'
        }
      }
    end

    def find_value(parameters)
      item, inventory_wh, title, item_mapping, inventory_wh_mapping,
      item_other_skus_barcodes = parameters

      if this_in_that(title, item_mapping)
        value_for(item, item_mapping[title])
      elsif this_in_that(title, inventory_wh_mapping)
        value_for(inventory_wh, inventory_wh_mapping[title])
      elsif this_in_that(title, item_other_skus_barcodes)
        attribute = item_other_skus_barcodes[title]
        find_other_skus_barcodes(item, title, attribute)
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
      ProductInventoryWarehouses.where(
        product_id: item.id,
        inventory_warehouse_id: InventoryWarehouse.where(
          is_default: true
        ).first.id
      ).first
    end

    def find_other_skus_barcodes(item, title, attribute)
      collection = item.send("product_#{attribute}s")
      index = title.gsub(/[^\d]/, '').to_i
      collection.length > 1 ? collection[index - 2].send(attribute) : ''
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
