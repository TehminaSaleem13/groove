# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      module MagentoRest
        module V2
          class OrdersImporter < Groovepacker::Stores::Importers::Importer
            def import
              handler = get_handler
              credential = handler[:credential]
              client = handler[:store_handle][:handle]
              import_item = handler[:import_item]
              result = build_result
              import_time = DateTime.now.in_time_zone
              begin
                orders = client.orders
                if orders.present? && orders['messages'].blank? && orders['message'].blank?
                  result[:total_imported] = orders.length
                  import_item.current_increment_id = ''
                  import_item.success_imported = 0
                  import_item.previous_imported = 0
                  import_item.current_order_items = -1
                  import_item.current_order_imported_item = -1
                  import_item.to_import = result[:total_imported]
                  import_item.save

                  orders.each do |order|
                    import_item = fix_import_item(import_item)
                    break if import_item.status == 'cancelled'

                    order = order.last
                    import_item.current_increment_id = order['increment_id']
                    import_item.current_order_items = -1
                    import_item.current_order_imported_item = -1
                    import_item.save

                    if Order.where(increment_id: order['increment_id']).empty?
                      @order = Order.new
                      @order.increment_id = order['increment_id']
                      @order.status = 'awaiting'
                      @order.order_placed_time = order['created_at'].to_datetime
                      @order.store = credential.store
                      line_items = order['items']

                      import_item.current_order_items = line_items.length
                      import_item.current_order_imported_item = 0
                      import_item.save
                      line_items.each do |line_item|
                        encoded_sku = URI.encode(line_item['sku'])
                        line_item_product = client.product(encoded_sku)
                        @order_item = OrderItem.new
                        @order_item.price = line_item['price']
                        @order_item.qty = line_item['qty_ordered']
                        @order_item.row_total = line_item['row_total']
                        @order_item.name = line_item['name']
                        @order_item.sku = line_item['sku']

                        product_id = if ProductSku.where(sku: @order_item.sku).empty?
                                       Groovepacker::Stores::Importers::MagentoRest::
                                       ProductsImporter.new(handler).import_single(line_item_product)
                                     else
                                       ProductSku.where(sku: @order_item.sku).first.product_id
                                     end
                        @order_item.product_id = product_id
                        @order.order_items << @order_item
                        import_item.current_order_imported_item = import_item.current_order_imported_item + 1
                        import_item.save
                      end

                      # if product does not exist import product using product.info
                      address = order['billing_address']
                      @order.address_1 = address['street'].join(', ')
                      @order.city = address['city']
                      @order.country = address['country_id']
                      @order.postcode = address['postcode']
                      @order.email = address['email']
                      @order.lastname = address['lastname']
                      @order.firstname = address['firstname']
                      @order.state = address['region']

                      if @order.save
                        unless @order.addnewitems
                          result[:status] &= false
                          result[:messages].push('Problem adding new items')
                         end
                        @order.addactivity('Order Import', credential.store.name + ' Import')
                        @order.order_items.each do |item|
                          @order.addactivity('Item with SKU: ' + item.sku + ' Added', credential.store.name + ' Import')
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
                else
                  response_error = if orders['message'].present?
                                     begin
                                        orders['message']
                                     rescue StandardError
                                       nil
                                      end
                                   else
                                     begin
                                        orders['messages']['error'].first['message']
                                     rescue StandardError
                                       nil
                                      end
                                   end
                  if response_error
                    result[:status] &= false
                    result[:messages].push(response_error)
                    import_item.status = 'failed'
                    import_item.message = response_error
                    import_item.save
                  end
                end
              rescue Exception => e
                result[:status] &= false
                result[:messages].push(e.message)
                import_item.status = 'failed'
                import_item.message = e.message
                import_item.save
                import_item = fix_import_item(import_item)
                tenant = Apartment::Tenant.current
                Rollbar.error(e, e.message, Apartment::Tenant.current)
                ImportMailer.failed(tenant: tenant, import_item: import_item, exception: e).deliver
              end
              import_item = fix_import_item(import_item)
              if (import_item.status != 'cancelled') && (import_item.status != 'failed')
                credential.last_imported_at = import_time
                credential.save
              end
              update_orders_status
              result
            end

            def import_single(_hash)
              {}
            end
          end
        end
      end
    end
  end
end
