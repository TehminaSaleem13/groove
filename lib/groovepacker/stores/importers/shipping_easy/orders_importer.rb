module Groovepacker
  module Stores
    module Importers
      module ShippingEasy
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper
          include ProductsImporter

          def import
            init_common_objects
            return @result if import_statuses_are_empty
            importing_time = Time.now
            response = @client.orders(@statuses, importing_time, @import_item)
            update_error_msg_if_any(response)
            destroy_cleared_orders(response)
            return @result if response["orders"].nil?
            @result[:total_imported] = response["orders"].length
            update_import_item_obj_values
            response["orders"].each do |order|
              order_copy = order["order"]
              order = order_copy unless order_copy.blank? 
              @order_to_update = false 
              @import_item = ImportItem.find_by_id(@import_item.id) rescue @import_item
              break if @import_item.status == 'cancelled'
              import_single_order(order)
              #increase_import_count
              sleep 0.5
            end

            @credential.update_attributes(last_imported_at: importing_time) if @result[:status] && @import_item.status != 'cancelled'
            update_orders_status
            @result
          end

          private
            def import_single_order(order)
              update_current_import_item(order)
              
              shiping_easy_order = Order.find_by_increment_id(order["external_order_identifier"])
              shiping_easy_order ||= Order.new

              return if shiping_easy_order.persisted? and shiping_easy_order.status=="scanned"
              @order_to_update = true if shiping_easy_order.persisted?
              shiping_easy_order.order_items.destroy_all
              shiping_easy_order.store_id = @credential.store_id

              import_order(shiping_easy_order, order)
              shiping_easy_order.tracking_num = order["shipments"][0]["tracking_number"] rescue nil
              import_order_items_and_create_products(shiping_easy_order, order)
              update_success_import_count
            end

            def create_alias_and_product(order_item, item)
              s3_image_url = create_s3_image(item) if item["product"]["image"].present? && item["product"]["image"]["original"].present?
              sku = item["product"]["sku"]
              alias_skus = item["product"]["sku_aliases"]
              store_product_id =  item["ext_line_item_id"]
              product = create_product(sku, item["product"], store_product_id)
              create_alias(alias_skus, product) if alias_skus
              (item["product"]["bundled_products"] || []).each do |kit_product|
                kit_pro = Product.joins(:product_skus).where("sku = ?", kit_product["sku"]) 
                new_kit_product = kit_pro.blank? ? create_product(kit_product["sku"], kit_product, store_product_id) : kit_pro[0]
                product.product_kit_skuss.create(option_product_id: new_kit_product.id, qty: 1) rescue nil if ProductKitSkus.where(product_id: product.id, option_product_id: new_kit_product.id).blank?
                kit_alias = kit_product["sku_aliases"]
                create_alias(kit_alias, new_kit_product) if kit_alias 
                product.update_attribute(:is_kit, 1)
              end
              create_order_item(item, order_item)
              product.product_images.create(image: s3_image_url) if s3_image_url.present?
              product.set_product_status
            end

            def create_s3_image(item)
              image_data = Net::HTTP.get(URI.parse(item["product"]["image"]["original"]))
              # image_data = IO.read(open(item["product"]["image"]["original"]))
              file_name = Time.now.strftime('%d_%b_%Y_%I__%M_%p') + "_shipping_easy_" + item["ext_line_item_id"]
              tenant = Apartment::Tenant.current
              GroovS3.create_image(tenant, file_name, image_data, 'public_read')
              s3_image_url = ENV['S3_BASE_URL']+'/'+tenant+'/image/'+file_name
              return s3_image_url
            end

            def create_order_item(item, order_item)
              order_item_product = Product.joins(:product_skus).where("product_skus.sku = ?", item["sku"]).first rescue nil
              order_item.product = order_item_product 
              order_item.sku = item["sku"]
              order_item.save
              make_product_intangible(order_item.product) if order_item.product.present?
            end

            def create_alias(alias_skus, product)
              alias_skus.each do |alias_sku|
                product.product_skus.create(sku: alias_sku) rescue nil if !(product.product_skus.map(&:sku).include? alias_sku)
              end
            end

            def create_product(sku, product_hash, store_product_id)
              product = Product.includes(:product_skus).where("product_skus.sku = ?", sku)[0]
              if product.blank?
                product_weight = product_hash["weight_in_ounces"] || "0.0"
                product = Product.create(name: product_hash["description"], store: @credential.store ,store_product_id: store_product_id, weight: product_weight)
                product.product_skus.create(sku: sku)
                product.product_cats.create(category: product_hash["product_category_name"])
                product.product_lots.create(lot_number: product_hash["bin_picking_number"])
                product.set_product_status
              end
              product.product_barcodes.create(barcode: product_hash["upc"]) if product.product_barcodes.blank? 
              product
            end

            def import_order(shiping_easy_order, order)
              total_weight = order["recipients"][0]["original_order"]["total_weight_in_ounces"] rescue 0

              shiping_easy_order.assign_attributes( increment_id: order["external_order_identifier"],
                                                    store_order_id: order["id"],
                                                    order_placed_time: order["ordered_at"].to_datetime,
                                                    email: order["billing_email"],
                                                    shipping_amount: order["base_shipping_cost"],
                                                    order_total: order["total_excluding_tax"],
                                                    notes_internal: order["internal_notes"],
                                                    weight_oz: total_weight
                                                  )
              shiping_easy_order = update_shipping_address(shiping_easy_order, order)
            end

            def import_order_items_and_create_products(shiping_easy_order, order)
              unless order["recipients"].blank?
                import_item_count(order)
                order["recipients"][0]["line_items"].each do |item|
                  order_item = shiping_easy_order.order_items.build
                  import_order_item(order_item, item)
                  if @credential.includes_product && item["product"].present?
                    create_alias_and_product(order_item, item)
                  else
                    import_single_order_product(order_item, item)
                  end
                  import_item_count
                end
              end
              
              return unless shiping_easy_order.save
              add_order_activity(shiping_easy_order)
              shiping_easy_order.set_order_status
            end

            def import_order_item(ordr_item, item)
              ordr_item.assign_attributes( qty: item["quantity"],
                                            price: item["unit_price"],
                                            row_total: item["unit_price"].to_f * item["quantity"].to_f
                                          )
            end

            def import_single_order_product(order_item, item)
              #find_or_create_order_item_product is defined in products importer module
              order_item_product = find_or_create_order_item_product(item, @credential.store)
              order_item.product = order_item_product
              make_product_intangible(order_item.product)
            end

            def import_item_count(order=nil)
              unless order.blank?
                @import_item.current_order_items = order["recipients"][0]["line_items"].length
                @import_item.current_order_imported_item = 0
              else
                @import_item.current_order_imported_item = @import_item.current_order_imported_item + 1
              end
              @import_item.save
            end

            def init_common_objects
              handler = self.get_handler
              @credential = handler[:credential]
              @client = handler[:store_handle]
              @import_item = handler[:import_item]
              @import_item.update_attributes(updated_orders_import: 0)
              @result = self.build_result
              @statuses = get_statuses
            end

            def get_statuses
              status = ["cleared"]
              status << "ready_for_shipment" if @credential.import_ready_for_shipment
              status << "shipped" if @credential.import_shipped
              status
            end

            def update_import_item_obj_values
              @import_item.update_attributes( current_increment_id: '', success_imported: 0, previous_imported: 0,
                                              current_order_items: -1, current_order_imported_item: -1, to_import: @result[:total_imported]
                                            )
            end

            def update_shipping_address(shiping_easy_order, order)
              return shiping_easy_order if order["recipients"].blank?
              ship_addr = order["recipients"][0]
              shiping_easy_order.assign_attributes( lastname: ship_addr["last_name"], firstname: ship_addr["first_name"], address_1: ship_addr["address"],
                                                    address_2: ship_addr["address2"], city: ship_addr["city"], state: ship_addr["state"],
                                                    postcode: ship_addr["postal_code"], country: ship_addr["country"]
                                                  )
              shiping_easy_order
            end

            def update_current_import_item(order)
              @import_item.update_attributes( 
                current_increment_id: order.try(:[], "external_order_identifier"),
                current_order_items: -1,
                current_order_imported_item: -1 
              )
            end

            def increase_import_count
              @result[:previous_imported] = @result[:previous_imported] + 1
              @import_item.previous_imported = @result[:previous_imported]
              @import_item.save
            end

            def import_statuses_are_empty
              return false unless @statuses.empty?
              @result[:status] = false
              @result[:messages].push('All import statuses disabled. Import skipped.')
              @import_item.update_attributes(message: 'All import statuses disabled. Import skipped.')
              return true
            end

            def add_order_activity(shiping_easy_order)
              shiping_easy_order.addactivity("Order Import", "#{@credential.store.name} Import")
              shiping_easy_order.order_items.each do |item|
                primary_sku = item.product.try(:primary_sku)
                next if primary_sku.nil?
                shiping_easy_order.addactivity("Item with SKU: #{primary_sku} Added", "#{@credential.store.name} Import")
              end
            end

            def destroy_cleared_orders(response)
              orders_to_clear = Order.where("store_id=? and status!=? and increment_id in (?)", @credential.store_id, "scanned", response["cleared_orders_ids"])
              orders_to_clear.destroy_all
            end

            def update_error_msg_if_any(response)
              return if response["error"].blank?
              @result[:status] &= false
              @result[:messages].push(response["error"]["message"])
              @import_item.message = response["error"]["message"]
              @import_item.save
            end
        end
      end
    end
  end
end