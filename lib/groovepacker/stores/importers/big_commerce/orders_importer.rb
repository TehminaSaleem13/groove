module Groovepacker
  module Stores
    module Importers
      module BigCommerce
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def import
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle]
            import_item = handler[:import_item]
            result = self.build_result
            response = client.orders(credential)
            
            #========
            credential.update_attributes( :last_imported_at => Time.now )
            result[:total_imported] = response["orders"].nil? ? 0 : response["orders"].length

            import_item.update_attributes(:current_increment_id => '', :success_imported => 0, :previous_imported => 0, :current_order_items => -1, :current_order_imported_item => -1, :to_import => result[:total_imported])

            (response["orders"]||[]).each do |order|
              import_item.update_attributes(:current_increment_id => order["id"], :current_order_items => -1, :current_order_imported_item => -1)
              
              #order = Order.where(increment_id: order["id"])
              if existing_order = Order.find_by_increment_id(order["id"])
                existing_order.destroy
              end

              #create order
              bigcommerce_order = Order.new
              import_order(bigcommerce_order, order, client)

              #import items in an order
              unless order["products"].nil?
                order["products"] = client.order_products(order["products"]["url"])
                import_item.update_attributes(:current_order_items => order["products"].length, :current_order_imported_item => 0 )

                (order["products"]||[]).each do |item|
                  order_item = OrderItem.new
                  import_order_item(order_item, item)
                  import_item.current_order_imported_item += 1
                  import_item.save

                  product_is_nil = Product.find_by_name(item["name"]).nil?
                  if item["sku"].nil? or item["sku"] == ''
                    # if sku is nil or empty
                    if product_is_nil
                    # and if item is not found by name then create the item
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
                    order_item_product = ProductSku.where(sku: item["sku"]).first.product
                    order_item.product = order_item_product
                  end

                  bigcommerce_order.order_items << order_item
                end
              end

              #update store
              bigcommerce_order.store = credential.store
              bigcommerce_order.save
              bigcommerce_order.set_order_status

              #add order activities
              bigcommerce_order.addactivity("Order Import", credential.store.name+" Import")
              (bigcommerce_order.order_items||[]).each do |item|
                unless item.product.nil? || item.product.primary_sku.nil?
                  bigcommerce_order.addactivity("Item with SKU: "+item.product.primary_sku+" Added", credential.store.name+" Import")
                end
              end

              import_item.success_imported += 1
              import_item.save
              result[:success_imported] += 1
            end

            #========
            result
          end

          def import_order(bigcommerce_order, order, client)
            bigcommerce_order.increment_id = order["id"]
            bigcommerce_order.store_order_id = order["id"].to_s
            bigcommerce_order.order_placed_time = order["date_created"].to_datetime

            unless order["customer_id"].nil?
              order["customer"] = client.customer("https://api.bigcommerce.com/stores/w9xil/v2/customers/#{order["customer_id"]}")
              bigcommerce_order.email = order["customer"]["email"]
              bigcommerce_order.lastname = order["customer"]["last_name"]
              bigcommerce_order.firstname = order["customer"]["first_name"]
            end
            
            unless order["shipping_addresses"].nil?
              shipping_addresses = client.shipping_addresses(order["shipping_addresses"]["url"])
              shipping_address = shipping_addresses.first
              bigcommerce_order.address_1 = shipping_address["street_1"]
              bigcommerce_order.address_2 = shipping_address["street_2"]
              bigcommerce_order.city = shipping_address["city"]
              bigcommerce_order.state = shipping_address["state"]
              bigcommerce_order.postcode = shipping_address["zip"]
              bigcommerce_order.country = shipping_address["country"]
            end

            bigcommerce_order.customer_comments = order["customer_message"]
            bigcommerce_order.qty = order["items_total"]

          end

          def import_order_item(order_item, line_item)
            order_item.sku = line_item["sku"]
            order_item.name = line_item["name"]
            order_item.qty = line_item["quantity"]
            order_item.price = line_item["base_price"]
            order_item.row_total = line_item["base_price"].to_f *
              line_item["quantity"].to_f
            order_item
          end

          def create_new_product_from_order(item, store, sku, client)
            #create and import product
            product = Product.create(name: item["name"], store: store,
                                     store_product_id: item["product_id"])
            product.product_skus.create(sku: sku)

            #get from products api
            bigcommerce_product = client.product(item["product_id"])
            unless bigcommerce_product.nil?
              barcode = bigcommerce_product["upc"].blank? ? nil : bigcommerce_product["upc"]
              product.product_barcodes.create(barcode: barcode)
              # get product categories
              unless bigcommerce_product["categories"].blank?
                tags = []
                categories = client.product_categories("https://api.bigcommerce.com/stores/w9xil/v2/categories")
                categories.select {|cat| tags << cat["name"] if bigcommerce_product["categories"].include?(cat["id"])}
                tags.each do |tag|
                  product.product_cats.create(category: tag)
                end
              end

              unless bigcommerce_product["skus"].empty? #Product skus are variants in BigCommerce
                product_skus = client.product_skus(bigcommerce_product["skus"]["url"]) || []
                product_skus.each do |variant|
                  next unless variant["sku"] == sku
                  # create barcode
                  barcode = variant["upc"].blank? ? nil : variant["upc"]
                  product.product_barcodes.create(barcode: barcode)
                  # get image based on the variant id
                  images = client.product_images(bigcommerce_product["images"]["url"])
                  (images||[]).each do |image|
                    product.product_images.create(image: image["src"])
                  end
                end
              end

              # if product images are empty then import product image
              if product.product_images.empty? && !bigcommerce_product["primary_image"].blank?
                product.product_images.create(image: bigcommerce_product["primary_image"]["standard_url"])
              end

            end
            product.save
            make_product_intangible(product)
            #product.update_product_status
            product.set_product_status
            product
          end
        end
      end
    end
  end
end
