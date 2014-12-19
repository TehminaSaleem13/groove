module Groovepacker
  module Store
    module Importers
      module Shipworks
        include ProductsHelper
        class OrdersImporter < Groovepacker::Store::Importers::Importer
          def import_order(order)
            handler = self.get_handler
            credential = handler[:credential]
            store = handler[:store_handle]
            import_item = handler[:import_item]

            #order["OnlineStatus"] == 'Processing'
            if allowed_status_to_import?(credential, order["Status"]) &&
              Order.find_by_increment_id(order["Number"]).nil?
              puts "Importing Order"
              import_item.current_increment_id = order["Number"]
              import_item.save
              ship_address = get_ship_address(order)
              order_m = Order.create(
                increment_id: order["Number"],
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
                order_total: order["Total"])

              import_item.current_order_items = order["Item"].length
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
              puts "Not Importing Order invalid status"
            end
          end

          private
          def allowed_status_to_import?(credential, status)
            return false if status.nil? && !credential.shall_import_no_status
            return true if status.nil? && credential.shall_import_no_status
            return true if status.strip == 'In Process' && credential.shall_import_in_process
            return true if status.strip == 'New Order' && credential.shall_import_new_order
            return true if status.strip == 'Not Shipped' && credential.shall_import_not_shipped
            return true if status.strip == 'Shipped' && credential.shall_import_shipped
            return false
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

          def import_order_item(item, import_item, order, store)
            sku = nil
            sku = item["SKU"] unless item["SKU"].nil?
            sku = item["Code"] unless item["Code"].nil? || item["Code"] == item["SKU"]
            if !sku.nil? && ProductSku.find_by_sku(sku)
              product = ProductSku.find_by_sku(sku).product
            else
              product = import_product(item, store)
            end

            order.order_items.create(
              product: product,
              price: item["UnitPrice"],
              qty: item["Quantity"],
              row_total: item["TotalPrice"]
            )
            import_item.current_order_imported_item = import_item.current_order_imported_item + 1
            import_item.save
          end

          def import_product(item, store)
            product = Product.create(
              store: store,
              name: item["Name"],
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
              product.product_skus.create(sku:  ProductSku.get_temp_sku)
            end

            #Barcodes
            product.product_barcodes.create(
              barcode: item["UPC"]
            ) unless item["UPC"].nil?

            #Images
            product.product_images.create(
              image: item["Image"]
            ) unless item["Image"].nil?

            #Location
            unless item["Location"].nil?
              inv_wh = ProductInventoryWarehouses.find_or_create_by_product_id_and_inventory_warehouse_id(product.id , store.inventory_warehouse_id)
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
 #    puts "********* IMPORT SHIPWORKS *********"
 #    puts params.inspect
 #    shipworks = params["ShipWorks"]
 #    order = Order.new

 #    order.increment_id = shipworks["Order"]["Number"]
 #    order.
 #  end
