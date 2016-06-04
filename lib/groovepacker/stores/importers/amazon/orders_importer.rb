module Groovepacker
  module Stores
    module Importers
      module Amazon
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          def import
            handler = self.get_handler
            mws = handler[:store_handle][:main_handle]
            credential = handler[:credential]
            import_item = handler[:import_item]
            result = self.build_result

            begin
              response = mws.orders.list_orders :last_updated_after => 2.months.ago, :order_status => ['Unshipped', 'PartiallyShipped']

              @orders = []
              if !response.orders.kind_of?(Array) &&
                !response.orders.nil?
                @orders.push(response.orders)
              else
                @orders = response.orders
              end

              if !@orders.nil?
                result[:total_imported] = @orders.length
                import_item.current_increment_id = ''
                import_item.success_imported = 0
                import_item.previous_imported = 0
                import_item.current_order_items = -1
                import_item.current_order_imported_item = -1
                import_item.to_import = result[:total_imported]
                import_item.save
                @orders.each do |order|
                  import_item.reload
                  break if import_item.status == 'cancelled'
                  import_item.current_increment_id = order.amazon_order_id
                  import_item.current_order_items = -1
                  import_item.current_order_imported_item = -1
                  import_item.save
                  if Order.where(:increment_id => order.amazon_order_id).length == 0
                    @order = Order.new
                    @order.status = 'awaiting'
                    @order.increment_id = order.amazon_order_id
                    @order.order_placed_time = order.purchase_date
                    @order.store = credential.store

                    order_items = mws.orders.list_order_items :amazon_order_id => order.amazon_order_id
                    import_item.current_order_items = order_items.length
                    import_item.current_order_imported_item = 0
                    import_item.save
                    # next if order_items.order_items[0].blank?
                    order_items.order_items.each do |item|
                      order_item = OrderItem.new
                      unless item.item_price.nil?
                        order_item.price = item.item_price.amount
                        unless item.item_price.amount.nil? && item.quantity_ordered.nil?
                          order_item.row_total= item.item_price.amount.to_i *
                            item.quantity_ordered.to_i
                        end
                      end
                      order_item.qty = item.quantity_ordered
                      order_item.sku = item.seller_sku

                      if ProductSku.where(:sku => item.seller_sku).length == 0
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
                        Groovepacker::Stores::Importers::Amazon::
                            ProductsImporter.new(handler).import_single({
                                                                          product_sku: item.seller_sku,
                                                                          product_id: product.id,
                                                                          handler: handler
                                                                        })
                        order_item.product = product
                      else
                        order_item.product = ProductSku.where(:sku => item.seller_sku).
                          first.product
                      end
                      order_item.name = item.title
                      @order.order_items << order_item
                      import_item.current_order_imported_item = import_item.current_order_imported_item + 1
                      import_item.save
                    end

                    unless order.shipping_address.nil?
                      @order.address_1 = order.shipping_address.address_line1
                      @order.city = order.shipping_address.city
                      @order.country = order.shipping_address.country_code
                      @order.postcode = order.shipping_address.postal_code
                      @order.state = order.shipping_address.state_or_region
                      @order.email = order.buyer_email
                      @order.lastname = order.shipping_address.name
                      split_name = order.shipping_address.name.split(' ')
                      @order.lastname = split_name.pop
                      @order.firstname = split_name.join(' ')
                    end

                    if @order.save
                      if !@order.addnewitems
                        result[:status] &= false
                        result[:messages].push('Problem adding new items')
                      end

                      @order.addactivity("Order Import", credential.store.name+" Import")
                      @order.order_items.each do |item|
                        if item.qty.blank? || item.qty<1
                        @order.addactivity("Item with SKU: #{item.product.primary_sku} had QTY of 0 and was removed:", "#{credential.store.name} Import")
                        item.destroy
                          next
                        end
                        unless item.product.nil? || item.product.primary_sku.nil?
                         @order.addactivity("Item with SKU: "+item.sku+" Added", credential.store.name+" Import")
                        end 
                      end
                      @order.set_order_status
                      result[:success_imported] = result[:success_imported] + 1
                      import_item.success_imported = result[:success_imported]
                      import_item.save
                    end
                  else
                    result[:previous_imported] = result[:previous_imported] + 1
                    import_item.previous_imported = result[:previous_imported]
                    import_item.save
                  end
                end
              end
            rescue Exception => e
              result[:status] &= false
              result[:messages].push(e.message)
              import_item.message = e.message
              import_item.save
            end
            result
          end

          #import order ends

          def import_single(hash)
            {}
          end
        end
      end
    end
  end
end
