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

            puts "****** ORDER ******"
            puts order.inspect
            puts "****** STORE ******"
            puts store.inspect

            if order["OnlineStatus"] == 'Processing' &&
              Order.find_by_increment_id(order["Number"]).nil?
              order_m = Order.create(
                increment_id: order["Number"],
                order_placed_time: order["Date"],
                store: store,
                lastname: order["Address"][0]["LastName"],
                firstname: order["Address"][0]["FirstName"],
                address_1: order["Address"][0]["Line1"],
                address_2: order["Address"][0]["Line2"],
                city: order["Address"][0]["City"],
                state: order["Address"][0]["StateName"],
                postcode: order["Address"][0]["PostalCode"],
                country: order["Address"][0]["CountryCode"],
                order_total: order["Total"])

              order["Item"].each do |item|
                if !item["SKU"].nil? && ProductSku.find_by_sku(item["SKU"])
                  product = ProductSku.find_by_sku(item["SKU"]).product
                else
                  product = import_product(item, store)
                end
                order_m.order_items.create(
                  product: product, 
                  price: item["UnitPrice"],
                  qty: item["Quantity"],
                  row_total: item["TotalPrice"]
                )
              end

              order_m.update_order_status
            end

            private

            def import_product(item, store)
              product = Product.create(
                store: store, 
                name: item["Name"],
                weight: item["Weight"],
                store_product_id: item["ID"]
              )

              #SKU
              if item["SKU"].nil?
                sku = ProductSku.get_temp_sku
              else
                sku = item["SKU"]
              end
              product.product_skus.create(sku: sku)

              #Barcodes
              product.product_barcodes.create(
                barcode: item["UPC"]
              ) unless item["UPC"].nil?

              #Images
              product.product_images.create(
                image: item["Image"]
              ) unless item["Image"].nil?

              #Location
              product.product_inventory_warehousess.create(
                inventory_warehouse: store.inventory_warehouse,
                location_primary: item["Location"]
              ) unless item["Location"].nil?

              product.set_product_status
            end

            #create order items
            # shipstation_order.postcode = order.ship_postal_code unless order.ship_postal_code.nil?
            # shipstation_order.country = order.ship_country_code 
            # shipstation_order.shipping_amount = order.shipping_amount unless order.shipping_amount.nil?
            # shipstation_order.order_total = order.order_total
            # shipstation_order.notes_from_buyer = order.notes_from_buyer unless order.notes_from_buyer.nil?
            # shipstation_order.weight_oz = order.weight_oz unless order.weight_oz.nil?
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