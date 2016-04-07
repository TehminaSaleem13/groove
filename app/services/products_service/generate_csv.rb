module ProductsService
  class GenerateCSV < ProductsService::ServiceInit
    attr_accessor :products, :csv, :bulk_actions_id

    def initialize(*args)
      @products, @csv, @bulk_actions_id = args
    end

    def call
      # @bulk_action = GrooveBulkActions.find(bulk_actions_id) if bulk_actions_id
      # headers = []
      # headers.push('ID', 'Name', 'SKU 1', 'Barcode 1', 'BinLocation 1', 'QOH', 'Primary Image', 'Weight', 'Primary Category',
      #              'SKU 2', 'SKU 3', 'Barcode 2', 'Barcode 3', 'BinLocation 2', 'BinLocation 3')
      # Product.column_names.each do |name|
      #   unless headers.any? { |s| s.casecmp(name)==0 }
      #     headers.push(name)
      #   end
      # end
      # csv << headers
      # products.each do |item|
      #   data = []
      #   inventory_wh = ProductInventoryWarehouses.where(:product_id => item.id, :inventory_warehouse_id => InventoryWarehouse.where(:is_default => true).first.id).first
      #   headers.each do |title|
      #     if title == 'ID'
      #       data.push(item.id)
      #     elsif title == 'Name'
      #       data.push(item.name)
      #     elsif title == 'SKU 1'
      #       data.push(item.primary_sku)
      #     elsif title == 'Barcode 1'
      #       data.push(item.primary_barcode)
      #     elsif title == 'BinLocation 1'
      #       data.push(inventory_wh.location_primary)
      #     # elsif title == 'Quantity Avbl'
      #     #   data.push(inventory_wh.available_inv)
      #     elsif title == 'QOH'
      #       data.push(inventory_wh.quantity_on_hand)
      #     elsif title == 'Primary Image'
      #       data.push(item.primary_image)
      #     elsif title == 'Weight'
      #       data.push(item.weight)
      #     elsif title == 'Primary Category'
      #       data.push(item.primary_category)
      #     elsif title == 'SKU 2'
      #       if item.product_skus.length >1
      #         data.push(item.product_skus[1].sku)
      #       else
      #         data.push('')
      #       end
      #     elsif title == 'SKU 3'
      #       if item.product_skus.length >2
      #         data.push(item.product_skus[2].sku)
      #       else
      #         data.push('')
      #       end
      #     elsif title == 'Barcode 2'
      #       if item.product_barcodes.length >1
      #         data.push(item.product_barcodes[1].barcode)
      #       else
      #         data.push('')
      #       end
      #     elsif title == 'Barcode 3'
      #       if item.product_barcodes.length >2
      #         data.push(item.product_barcodes[2].barcode)
      #       else
      #         data.push('')
      #       end
      #     elsif title == 'BinLocation 2'
      #       data.push(inventory_wh.location_secondary)
      #     elsif title == 'BinLocation 3'
      #       data.push('')
      #     else
      #       data.push(item.attributes.values_at(title).first) unless item.attributes.values_at(title).empty?
      #     end
      #   end
      #   if @bulk_action
      #     @bulk_action.completed += 1
      #     @bulk_action.save
      #   end
      #   csv << data
      # end
      # csv
    end
  end
end
