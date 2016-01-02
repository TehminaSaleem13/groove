module Groovepacker
  module Stores
    module Importers
      module Shopify
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def import
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle]
            import_item = handler[:import_item]
            result = self.build_result

            response = client.orders

            result[:total_imported] =
              response["orders"].nil? ? 0 : response["orders"].length

            import_item.current_increment_id = ''
            import_item.success_imported = 0
            import_item.previous_imported = 0
            import_item.current_order_items = -1
            import_item.current_order_imported_item = -1
            import_item.to_import = result[:total_imported]
            import_item.save

            unless response["orders"].nil?
              response["orders"].each do |order|
                import_item.reload
                break if import_item.status == 'cancelled'
                import_item.current_increment_id = order["id"]
                import_item.current_order_items = -1
                import_item.current_order_imported_item = -1
                import_item.save
                shipstation_order = nil
                if Order.where(increment_id: order["id"]).empty?

                  #create order
                  shopify_order = Order.new
                  import_order(shopify_order, order)

                  #import items in an order
                  unless order["line_items"].nil?
                    import_item.current_order_items = order["line_items"].length
                    import_item.current_order_imported_item = 0
                    import_item.save

                    order["line_items"].each do |item|
                      order_item = OrderItem.new
                      import_order_item(order_item, item)
                      import_item.current_order_imported_item = import_item.current_order_imported_item + 1
                      import_item.save
                      if item["sku"].nil? or item["sku"] == ''
                        # if sku is nil or empty
                        if Product.find_by_name(item["name"]).nil?
                          # if item is not found by name then create the item
                          order_item.product = create_new_product_from_order(item, credential.store, ProductSku.get_temp_sku, client)
                        else
                          # product exists add temp sku if it does not exist
                          products = Product.where(name: item["name"])
                          unless contains_temp_skus(products)
                            order_item.product = create_new_product_from_order(item, credential.store, ProductSku.get_temp_sku, client)
                          else
                            order_item.product = get_product_with_temp_skus(products)
                          end
                        end
                      elsif ProductSku.where(sku: item["sku"]).length == 0
                        # if non-nil sku is not found
                        product = create_new_product_from_order(item, credential.store, item["sku"], client)
                        order_item.product = product
                      else
                        order_item_product = ProductSku.where(sku: item["sku"]).
                          first.product
                        order_item.product = order_item_product
                      end

                      shopify_order.order_items << order_item
                    end
                  end

                  #update store
                  shopify_order.store = credential.store
                  shopify_order.save
                  shopify_order.set_order_status

                  #add order activities
                  shopify_order.addactivity("Order Import", credential.store.name+" Import")
                  shopify_order.order_items.each do |item|
                    unless item.product.nil? || item.product.primary_sku.nil?
                      shopify_order.addactivity("Item with SKU: "+item.product.primary_sku+" Added", credential.store.name+" Import")
                    end
                  end


                  import_item.success_imported = import_item.success_imported + 1
                  import_item.save
                  result[:success_imported] = result[:success_imported] + 1
                else
                  #mark previously imported
                  import_item.previous_imported = import_item.previous_imported + 1
                  import_item.save
                  result[:previous_imported] = result[:previous_imported] + 1
                end
              end
            end

            result
          end

          def import_order(shopify_order, order)
            shopify_order.increment_id = order["order_number"] 
            shopify_order.store_order_id = order["id"].to_s
            shopify_order.order_placed_time = order["created_at"]

            unless order["customer"].nil?
              shopify_order.email = order["customer"]["email"]
              shopify_order.lastname = order["customer"]["last_name"]
              shopify_order.firstname = order["customer"]["first_name"]
            end

            unless order["shipping_address"].nil?
              shopify_order.address_1 = order["shipping_address"]["address1"] unless order["shipping_address"]["address1"].nil?
              shopify_order.address_2 = order["shipping_address"]["address2"] unless order["shipping_address"]["address2"].nil?
              shopify_order.city = order["shipping_address"]["city"] unless order["shipping_address"]["city"].nil?
              shopify_order.state = order["shipping_address"]["province"] unless order["shipping_address"]["province"].nil?
              shopify_order.postcode = order["shipping_address"]["zip"] unless order["shipping_address"]["zip"].nil?
              shopify_order.country = order["shipping_address"]["country"] unless order["shipping_address"]["country"].nil?
            end

            unless order["shipping_lines"].nil? ||
              order["shipping_lines"].empty?
              shipping = order["shipping_lines"].first
              shopify_order.shipping_amount =
                shipping["price"].to_f unless shipping.nil?
            end

            shopify_order.weight_oz = (order["total_weight"].to_i * 0.035274) unless order["total_weight"].nil?
            shopify_order.order_total = order["total_price"].to_f unless order["total_price"].nil?
          end

          def import_order_item(order_item, line_item)
            order_item.qty = line_item["quantity"]
            order_item.price = line_item["price"]
            order_item.row_total = line_item["price"].to_f *
              line_item["quantity"].to_f
            order_item
          end

          def create_new_product_from_order(item, store, sku, client)
            #create and import product
            product = Product.create(name: item["name"], store: store,
                                     store_product_id: item["product_id"])
            product.product_skus.create(sku: sku)

            #get from products api
            response = client.product(item["product_id"])

            shopify_product = response["product"]
            unless shopify_product.nil?
              # get product categories
              unless shopify_product["tags"].nil? ||
                shopify_product["tags"] == ""
                tags = shopify_product["tags"].split(", ")
                tags.each do |tag|
                  product.product_cats.create(category: tag)
                end
              end

              unless shopify_product["variants"].empty?
                # get variant id based on the sku
                variant_id = nil
                shopify_product["variants"].each do |variant|
                  if variant["sku"] == sku
                    # create barcode
                    product.product_barcodes.create(barcode: variant["barcode"])
                    # get image based on the variant id
                    shopify_product["images"].each do |image|
                      if image["variant_ids"].include?(variant["if"])
                        product.product_images.create(image: image["src"])
                      end
                    end

                    # get weight
                    if variant["weight_unit"] == 'lb'
                      product.weight = variant["weight"] * 16
                    elsif variant["weight_unit"] == 'kg'
                      product.weight = variant["weight"] * 35.274
                    elsif variant["weight_unit"] == 'g'
                      product.weight = variant["weight"] * 0.035274
                    elsif variant["weight_unit"] == 'oz'
                      product.weight = variant["weight"]
                    end
                  end
                end
              end

              # if product images are empty then import product image
              if product.product_images.empty? &&
                !shopify_product["image"].nil? &&
                shopify_product["image"] != ''
                product.product_images.create(image: shopify_product["image"]["src"])
              end

            end
            product.save
            make_product_intangible(product)
            product.update_product_status
            product
          end
        end
      end
    end
  end
end
