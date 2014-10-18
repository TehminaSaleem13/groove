module Groovepacker
  module Store
    module Importers
      module Shipworks
        include ProductsHelper
        class OrdersImporter < Groovepacker::Store::Importers::Importer
          def import_order(order)
            puts "****** ORDER ******"
            puts order.inspect
            # shipstation_order.increment_id = order.order_number
            # shipstation_order.seller_id = order.seller_id
            # shipstation_order.order_status_id = order.order_status_id
            # shipstation_order.order_placed_time = order.order_date 
            # split_name = order.ship_name.split(' ')
            # shipstation_order.lastname = split_name.pop
            # shipstation_order.firstname = split_name.join(' ')
            # shipstation_order.email = order.buyer_email unless order.buyer_email.nil?
            # shipstation_order.address_1 = order.ship_street1
            # shipstation_order.address_2 = order.ship_street2 unless order.ship_street2.nil?
            # shipstation_order.city = order.ship_city
            # shipstation_order.state = order.ship_state
            # shipstation_order.postcode = order.ship_postal_code unless order.ship_postal_code.nil?
            # shipstation_order.country = order.ship_country_code 
            # shipstation_order.shipping_amount = order.shipping_amount unless order.shipping_amount.nil?
            # shipstation_order.order_total = order.order_total
            # shipstation_order.notes_from_buyer = order.notes_from_buyer unless order.notes_from_buyer.nil?
            # shipstation_order.weight_oz = order.weight_oz unless order.weight_oz.nil?
          end

          # def import_order_item(order_item, item)
          #   order_item.sku = item.sku unless item.sku.nil?
          #   order_item.qty = item.quantity
          #   order_item.price = item.unit_price
          #   order_item.name = item.description
          #   order_item.row_total = item.unit_price.to_f * 
          #   item.quantity.to_i
          #   order_item.product_id = item.product_id unless item.product_id.nil?
          #   order_item.order_id = item.order_id
          # end

          # def create_new_product_from_order(item, store, sku)
          #   #create and import product
          #   product = Product.create(name: item.description, store: store,
          #     store_product_id: 0)
          #   product.product_skus.create(sku: sku)
          #   #Build Image
          #   unless item.thumbnail_url.nil? || product.product_images.length > 0
          #     product.product_images.create(image: item.thumbnail_url)
          #   end                          

          #   #build barcode
          #   unless item.upc.nil? || product.product_barcodes.length > 0
          #     product.product_barcodes.create(barcode: item.upc)
          #   end
          #   product
          # end

          # def import_single(hash)
          #   {}
          # end
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