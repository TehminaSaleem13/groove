module Groovepacker
  module Stores
    module Importers
      module Shipworks
        include ProductsHelper
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          def import_order(order)
            handler = self.get_handler
            credential = handler[:credential]
            store = handler[:store_handle]
            import_item = handler[:import_item]
            #order["OnlineStatus"] == 'Processing'
            if import_item.status != 'cancelled'
              order_number = get_order_number(order, credential)
              if credential.can_import_an_order?
                if allowed_status_to_import?(credential, order["Status"])
                  if Order.find_by_increment_id(order_number).nil?
                    import_item.current_increment_id =order_number
                    import_item.save
                    ship_address = get_ship_address(order)
                    tracking_num = nil
                    tracking_num = order["Shipment"]["TrackingNumber"]  if order["Shipment"].class.to_s.include?("Hash")
                    notes_internal = get_internal_notes(order) unless order["Note"].nil?

                    order_m = Order.create(
                      increment_id: order_number,
                      order_placed_time: order["Date"],
                      store: store,
                      email: ship_address["Email"],
                      lastname: ship_address["LastName"],
                      firstname: ship_address["FirstName"],
                      address_1: ship_address["Line1"],
                      address_2: ship_address["Line2"],
                      city: ship_address["City"],
                      state: ship_address["StateName"],
                      postcode: ship_address["PostalCode"],
                      country: ship_address["CountryCode"],
                      order_total: order["Total"],
                      tracking_num: tracking_num,
                      notes_internal: notes_internal)

                    import_item.current_order_items = order["Item"].length rescue 0
                    import_item.current_order_imported_item = 0
                    import_item.save

                    if order["Item"].is_a? (Array)
                      order["Item"].each do |item|
                        import_order_item(item, import_item, order_m, store)
                      end
                    else
                      import_order_item(order["Item"], import_item, order_m, store)
                    end

                    order_m.set_order_status
                    import_item.success_imported = 1
                    import_item.save

                    order_m.addactivity("Order Import", store.name+" Import")
                    order_m.order_items.each do |item|
                      unless item.product.nil? || item.product.primary_sku.nil?
                        order_m.addactivity("Item with SKU: "+item.product.primary_sku+" Added", store.name+" Import")
                      end
                    end
                  else
                    import_item.status = 'failed'
                    import_item.message = 'No new orders with the currently enabled statuses.'
                    import_item.save
                  end
                else
                  import_item.status = 'failed'
                  import_item.message = 'No incoming orders with the currently enabled statuses.'
                  import_item.save
                end
              else
                import_item.status = 'failed'
                import_item.message = 'No incoming orders with the currently enabled statuses.'
                import_item.save
              end
            end
            update_orders_status
          end

          private
          def allowed_status_to_import?(credential, status)
            return true if credential.shall_import_ignore_local
            return false if status.nil? && !credential.shall_import_no_status
            return true if status.nil? && credential.shall_import_no_status
            return true if status.strip == 'In Process' && credential.shall_import_in_process
            return true if status.strip == 'New Order' && credential.shall_import_new_order
            return true if status.strip == 'Not Shipped' && credential.shall_import_not_shipped
            return true if status.strip == 'Shipped' && credential.shall_import_shipped
            return false
          end

          def get_order_number(order, credential)
            if credential.import_store_order_number && !order["Amazon"].nil?
              order["Amazon"]["AmazonOrderID"]
            else
              order["Number"]
            end
          end

          def get_ship_address(order)
            result = nil

            order["Address"].each do |addr|
              if addr["type"] == "ship"
                result = addr
                break
              end
            end

            result
          end

          def get_internal_notes(order)
            internal_notes = nil
            # if order["Note"] is array or hash
            if order["Note"].is_a?(Array)
              notes = []
              order["Note"].each do |note|
                if note["Visibility"] == "Internal"
                  notes << note["Text"]
                end
              end
              internal_notes = notes.join(" || ")
            else
              internal_notes = order["Note"]["Text"] if order["Note"]["Visibility"] == "Internal"
            end
            internal_notes
          end

          def import_order_item(item, import_item, order, store)
            sku = nil
            if item.present?
              if item["SKU"].present?
                sku = item["SKU"] 
              else 
                sku = item["Code"] if item["Code"].present? && item["Code"] != item["SKU"]
              end
            end
            if !sku.nil? && ProductSku.find_by_sku(sku)
              product = ProductSku.find_by_sku(sku).product
            else
              product = import_product(item, store) rescue nil
            end

            order.order_items.create(
              product: product,
              price: item["UnitPrice"].to_f,
              qty: item["Quantity"],
              row_total: item["TotalPrice"]
            )
            import_item.current_order_imported_item = import_item.current_order_imported_item + 1
            import_item.save
            #make_product_intangible(product)
          end

          def import_product(item, store)
            item_name = item["Name"].blank? ? "Product Created by Shipworks Import" : item["Name"]
            product = Product.create(
              store: store,
              name: item_name,
              weight: item["Weight"],
              store_product_id: item["ID"]
            )

            found_sku = false
            #SKU
            unless item["SKU"].nil?
              product.product_skus.create(sku: item["SKU"])
              found_sku = true
            end
            unless item["Code"].nil? || item["Code"] == item["SKU"]
              product.product_skus.create(sku: item["Code"])
              found_sku = true
            end

            unless found_sku
              product.product_skus.create(sku: ProductSku.get_temp_sku)
            end

            #Barcodes
            if item["UPC"].present?
              product.product_barcodes.create(
                barcode: item["UPC"]
              )
            elsif store.shipworks_credential.gen_barcode_from_sku && item["SKU"].present? && ProductBarcode.where(barcode: item["SKU"]).empty?
              product.product_barcodes.create(
                barcode: item["SKU"]
              )
            end

            #Images
            product.product_images.create(
              image: item["Image"]
            ) unless item["Image"].nil?

            #Location
            unless item["Location"].nil?
              inv_wh = ProductInventoryWarehouses.find_or_create_by_product_id_and_inventory_warehouse_id(product.id, store.inventory_warehouse_id)
              inv_wh.location_primary = item["Location"]
              inv_wh.save
            end

            product.set_product_status
            product
          end
        end
      end
    end
  end
end


# # temporary method for importing shipworks
#  def import_shipworks
#    shipworks = params["ShipWorks"]
#    order = Order.new

#    order.increment_id = shipworks["Order"]["Number"]
#    order.
#  end
