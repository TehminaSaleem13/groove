module Groovepacker
  module Store
    module Importers
      module Shipstation
        class OrdersImporter < Groovepacker::Store::Importers::Importer
          def import
            handler = self.get_handler
            credential = handler[:credential]
            shipstation = handler[:store_handle]
            result = self.build_result
            
            begin
              orders = client.order.all
              if !orders.nil?
                orders.each do |order|
                  if Order.where(:increment_id=>order.order_id).length == 0
                    @order = Order.new
                    @order.status = 'awaiting'
                    @order.increment_id = order.order_id
                    # @order.order_placed_time = order.purchase_date
                    # @order.store = credential.store
                  end
                end
              end
            rescue Exception => e
              result[:status] &= false
              result[:messages].push(e)
            end
            result
          end

          def import_single(hash)
            {}
          end

          
        end
      end
    end
  end
end