module Groovepacker
  module Orders
    module Xml
      class Import
        attr_accessor :order

        def initialize(file_name)
          @order = Groovepacker::Orders::Xml::OrderXml.new(file_name)
        end

        def process
          result = {status: true, errors: [], order: nil}
          order = Order.find_by_increment_id(@order.increment_id)
          # if order exists, update the order and order items
          # order does not exist create order
          if order.nil?
            order = Order.new
            order.increment_id = @order.increment_id
          end
          ["store_id", "firstname", "lastname", "email", "address_1", "address_2",
              "city", "state", "country", "postcode", "order_placed_time", "tracking_num", 
              "custom_field_one", "custom_field_two", "method", "order_total",
              "customer_comments", "notes_toPacker", "notes_fromPacker", "notes_internal", "price"].each do |attr|
              order[attr] = @order.send(attr)
          end
          # update all order related info
          order_persisted = order.persisted? ? true : false
          if order.save
            order.addactivity("Order Import", "#{order.store.name} Import") unless order_persisted
            # @order[:order_items] = @order.order_items
            order_item_result = process_order_items(order, @order)
            if order_item_result[:status]
              # update order status
              order.update_order_status
            else
              # order.destroy
            end
            result[:status] = order_item_result[:status]
            result[:errors] = order_item_result[:errors]
          else
            result[:status] = false
            result[:errors] = order.errors.full_messages
            result[:order] = nil
          end
          if result[:status]
            upload_res = @order.save
            if upload_res.nil?
              result[:status] = false 
              result[:errors] = ["Error uploading to S3."]
            else
              order.import_s3_key = upload_res
              order.save
            end
          end
          # update the importsummary if import summary is available
          if !@order.import_summary_id.nil?
            begin
              order_import_summary = OrderImportSummary.find(@order.import_summary_id)
              import_item = order_import_summary.import_items.where(store_id: order.store_id)
              unless import_item.empty?
                import_item = import_item.first
                import_item.with_lock do
                  import_item.to_import = @order.total_count
                  if result[:status]
                    import_item.status = "in_progress"
                    if order_persisted
                      import_item.previous_imported += 1
                    else
                      import_item.success_imported += 1
                    end
                  else
                    #import_summary.failed_imported += 1
                  end
                  # if all are finished then mark as completed
                  if import_item.previous_imported + import_item.success_imported == @order.total_count
                    import_item.status = "completed"
                  end
                  import_item.save
                end
              end
            rescue Exception => ex
              
            end
          end

          result
        end

        private
        def process_order_items(order, orderXML)
          result = { status: true, errors: [] }
          if order.order_items.empty?
            # create order items
            orderXML.order_items.each do |order_item_XML|
              create_update_order_item(order, order_item_XML)
            end
          else
            # if order item exists in the current order but does not exist in XML order
            # then delete the order item
            delete_existing_order_items(order, orderXML)

            orderXML.order_items.each do |order_item_XML|
              create_update_order_item(order, order_item_XML)
            end
          end
          result
        end

        def delete_existing_order_items(order, orderXML)
          order.order_items.each do |order_item|
            found = false
            first_sku = order_item.product.product_skus.first
            unless first_sku.nil?
              first_sku = first_sku.sku
              orderXML.order_items.each do |order_item_XML|
                unless order_item_XML[:product][:skus].index(first_sku).nil?
                  found = true
                end
              end
            end
            unless found
              order_item.destroy
            end
          end
        end

        def create_update_order_item(order, order_item_XML)
          first_sku = order_item_XML[:product][:skus].first
          unless first_sku.nil?
            product_sku = ProductSku.find_by_sku(first_sku)
            if product_sku.nil?
              # add product
              product = Product.new
              product.store = order.store
            else
              product = product_sku.product
            end

            result = create_update_product(product, order_item_XML[:product])
            if result[:status]
              if order.order_items.where(product_id: product.id).empty?
                order.order_items.create(sku: first_sku, qty: (order_item_XML[:qty] || 0),
                product_id: product.id, price: order_item_XML[:price])
                order.addactivity("Item with SKU: #{product.primary_sku} Added", 
                  "#{order.store.name} Import")
              else
                order_item = order.order_items.where(product_id: product.id)
                unless order_item.empty?
                  order_item = order_item.first
                  order_item.sku = first_sku
                  order_item.qty = order_item_XML[:qty] || 0
                  order_item.price = order_item_XML[:price]
                  order_item.save
                end
              end
            end
          end
        end

        def create_update_product(product, product_xml)
          result = {  status: true, errors: [], product: nil }
          #product information
          product.name = product_xml[:name] if product.name.blank?
          product.spl_instructions_4_packer = product_xml[:instructions] if product.spl_instructions_4_packer.blank?
          product.is_kit = product_xml[:is_kit] if product.is_kit == 0
          product.kit_parsing = product_xml[:kit_parsing] if product.kit_parsing.blank?
          product.weight = product_xml[:weight] if product.weight.blank?
          product.weight_format = product_xml[:weight_format] if product.weight_format.blank?
          if product.save
            product.set_product_status
            setting = ScanPackSetting.all.first
            intangible_strings = setting.intangible_string.split(",")
            intangible_setting_enabled = setting.intangible_setting_enabled
            if intangible_setting_enabled
              intangible_strings.each do |string|
                action_intangible = Groovepacker::Products::ActionIntangible.new
                if ((product.name).downcase.include? (string.downcase)) || action_intangible.send(:sku_starts_with_intangible_string, product, string)
                  product.is_intangible = false
                  product.save
                end
              end
            end
            #images
            product_xml[:images].each do |product_image|
              if product.product_images.where(image: product_image).empty?
                product.product_images.create(image: product_image)
              end
            end

            #categories
            product_xml[:categories].each do |product_category|
              if product.product_cats.where(category: product_category).empty?
                product.product_cats.create(category: product_category)
              end
            end

            #skus
            product_xml[:skus].each do |product_sku|
              if product.product_skus.where(sku: product_sku).empty?
                product.product_skus.create(sku: product_sku)
              end
            end

            #barcodes
            product_xml[:barcodes].each do |product_barcode|
              if product.product_barcodes.where(barcode: product_barcode).empty?
                product.product_barcodes.create(barcode: product_barcode)
              end
            end
            #product.update_product_status
            result[:product] = product
          else
            result[:status] = false
            result[:errors] = product.errors.full_messages
          end
          result
        end
      end
    end
  end
end