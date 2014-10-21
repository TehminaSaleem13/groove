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
            unless order["OnlineStatus"] != 'Processing'
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
            end
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