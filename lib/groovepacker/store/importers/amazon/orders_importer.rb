module Groovepacker
  module Store
    module Importers
      module Amazon
        class OrdersImporter < Groovepacker::Store::Importers::Importer
          def import
            handler = self.get_handler
            mws = handler[:store_handle][:main_handle]
            credential = handler[:credential]
            response = mws.orders.list_orders :last_updated_after => 2.months.ago, 
              :order_status => ['Unshipped', 'PartiallyShipped']
            result = self.build_result
            @orders = []

            if !response.orders.kind_of?(Array)
              @orders.push(response.orders)
            else
              @orders = response.orders
            end

            if !@orders.nil?
              @orders.each do |order|
                if Order.where(:increment_id=>order.amazon_order_id).length == 0
                  @order = Order.new
                  @order.status = 'awaiting'
                  @order.increment_id = order.amazon_order_id
                  @order.order_placed_time = order.purchase_date
                  @order.store = credential.store
                  
                  order_items  = 
                    mws.orders.list_order_items :amazon_order_id => order.amazon_order_id

                  order_items.order_items.each do |item|
                    @order_item = OrderItem.new
                    @order_item.price = item.item_price.amount
                    @order_item.qty = item.quantity_ordered
                    @order_item.row_total= item.item_price.amount.to_i * 
                      item.quantity_ordered.to_i
                    @order_item.sku = item.seller_sku

                    if ProductSku.where(:sku=>item.seller_sku).length == 0
                      #create and import product
                      product = Product.new
                      product.name = 'New imported item'
                      product.store_product_id = 0
                      product.store = credential.store

                      sku = ProductSku.new
                      sku.sku = item.seller_sku
                      product.product_skus << sku
                      product.save

                      #import other product details
                      Groovepacker::Store::Importers::Amazon::
                        ProductsImporter.new(handler).import_single({ 
                          product_sku: item.seller_sku, 
                          product_id: product.id, 
                          handler: handler
                        })
                    else
                      @order_item.product = ProductSku.where(:sku=>item.seller_sku).
                        first.product
                    end
                    @order_item.name = item.title
                  end

                  @order.order_items << @order_item

                  @order.address_1  = order.shipping_address.address_line1
                  @order.city = order.shipping_address.city
                  @order.country = order.shipping_address.country_code
                  @order.postcode = order.shipping_address.postal_code
                  @order.state = order.shipping_address.state_or_region
                  @order.email = order.buyer_email
                  @order.lastname = order.shipping_address.name
                  split_name = order.shipping_address.name.split(' ')
                  @order.lastname = split_name.pop
                  @order.firstname = split_name.join(' ')

                  if @order.save
                    if !@order.addnewitems
                      result[:status] &= false
                      result[:messages].push('Problem adding new items')
                    end
                    @order.addactivity("Order Import", credential.store.name+" Import")
                    @order.order_items.each do |item|
                      @order.addactivity("Item with SKU: "+item.sku+" Added", credential.store.name+" Import")
                    end
                    @order.set_order_status
                    result[:success_imported] = result[:success_imported] + 1
                  end
                else
                  result[:previous_imported] = result[:previous_imported] + 1
                end
              end
            end
            result
          end #import order ends

          def import_single(hash)
            {}
          end
        end
      end
    end
  end
end