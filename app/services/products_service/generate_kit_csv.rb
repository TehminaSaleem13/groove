module ProductsService
  class GenerateKitCSV < ProductsService::Base
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
        products.each do |kit|
          kit.kit_part_skus.each do |item|
            if @bulk_action
              @bulk_action.reload
              return true if bulk_action_cancelled?
            end
            @csv << process_data(item)
          end
        end
        @csv
      else
        @csv = CSV.generate(headers: true) do |csv|
          csv << headers.to_a
          products.each do |kit|
            kit.product_kit_skuss.each do |item|
              if @bulk_action
                @bulk_action.reload
                return true if bulk_action_cancelled?
              end
              csv << process_data(item)
            end
          end
        end
        @csv
      end
    end

    private

    def bulk_action?
      return unless bulk_actions_id
      @bulk_action = GrooveBulkActions.find(bulk_actions_id)
    end

    def set_header
      @headers = [
        'KIT-SKU', 'KIT-NAME', 'KIT-BARCODE', 'PART-SKU', 'PART-NAME', 'PART-BARCODE', 'PART-QTY', 'SCAN-OPTION', 'KIT-PART-SCANNING-SEQUENCE'
      ]
    end

    def process_data(item)
      data = []
      kit = item.product
      kit_item = Product.find_by_id(item.option_product_id)
      kit_item_sku_mapping = @data_mapping['kit_item_sku']
      kit_item_product_mapping = @data_mapping['kit_item_product']
      kit_mapping = @data_mapping['kit']
      headers.each do |title|
        data.push(
          find_value([
                       item, kit, kit_item, title, kit_item_sku_mapping, kit_item_product_mapping, kit_mapping
                     ])
        )
      end
      do_if_bulk_action
      data
    end

    def set_data_mapping
      @data_mapping = {
        'kit_item_sku' => {
          'PART-QTY' => 'qty',
          'KIT-PART-SCANNING-SEQUENCE' => 'packing_order'
        },
        'kit_item_product' => {
          'PART-SKU' => 'primary_sku',
          'PART-NAME' => 'name',
          'PART-BARCODE' => 'primary_barcode'
        },
        'kit' => {
          'KIT-SKU' => 'primary_sku',
          'KIT-NAME' => 'name',
          'KIT-BARCODE' => 'primary_barcode',
          'SCAN-OPTION' => 'kit_parsing'
        }
      }
    end

    def find_value(parameters)
      item, kit, kit_item, title, kit_item_sku_mapping, kit_item_product_mapping, kit_mapping = parameters
      if this_in_that(title, kit_item_sku_mapping)
        value_for(item, kit_item_sku_mapping[title])
      elsif this_in_that(title, kit_item_product_mapping)
        value_for(kit_item, kit_item_product_mapping[title])
      elsif this_in_that(title, kit_mapping)
        value = value_for(kit, kit_mapping[title])
        if title == 'SCAN-OPTION'
          case value
          when 'single'
            value = 1
          when 'individual'
            value = 2
          when 'depends'
            value = 3
          end
        end
        value
      end
    end

    def value_for(obj, method)
      obj.send(method)
    end

    def this_in_that(title, mapping)
      title.in? mapping.keys
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
