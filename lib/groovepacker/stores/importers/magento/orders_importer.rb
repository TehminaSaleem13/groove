  module Groovepacker
  module Stores
    module Importers
      module Magento
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          def import
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle][:handle]
            session = handler[:store_handle][:session]
            import_item = handler[:import_item]
            result = self.build_result
            import_time = DateTime.now
            begin
              orders_response = get_orders(client, credential, session, import_item)
              unless orders_response.blank?
                result[:total_imported] = orders_response.length
                import_item.current_increment_id = ''
                import_item.success_imported = 0
                import_item.previous_imported = 0
                import_item.current_order_items = -1
                import_item.current_order_imported_item = -1
                import_item.to_import = result[:total_imported]
                import_item.save
                orders_response.each do |item|
                  import_item = ImportItem.find_by_id(import_item.id) rescue import_item
                  break if import_item.status == 'cancelled'
                  next unless item.class.to_s.include?("Hash")
                  import_single_order(item, import_item, client, credential, session, result)
                end
              end
            rescue Exception => e
              result[:status] &= false
              result[:messages].push(e.message)
              import_item.message = e.message
              import_item.save
              tenant = Apartment::Tenant.current
              Rollbar.error(e, e.message)
              ImportMailer.failed({ tenant: tenant, import_item: import_item, exception: e }).deliver
            end
            import_item = ImportItem.find_by_id(import_item.id) rescue import_item

            if get_statuses_to_import(credential).blank?
              result[:status] = false
              import_item.message = 'All import statuses are disabled. Import skipped.'
              import_item.save
            elsif import_item.status != 'cancelled'
              credential.last_imported_at = import_time
              credential.save
            end
            update_orders_status
            result
          end

          def import_single(hash)
            {}
          end

          private
            def get_statuses_to_import(credential)
              statuses = []
              statuses << "processing" if credential.shall_import_processing
              statuses << "new" if credential.shall_import_pending
              statuses << "closed" if credential.shall_import_closed
              statuses << "complete" if credential.shall_import_complete
              statuses << "payment_review" if credential.shall_import_fraud
              return statuses
            end

            def get_filters(status, credential, import_item)
              @filters_array = {}
              @filters = {}
              @filter = {}
              item = {}
              item['key'] = 'state'
              item['value'] = status
              @filter['item'] = item
              @filters['filter'] = @filter
              @filters_array = @filters

              @filters1 = {}
              @filter1 = {}
              item1 = {}
              if import_item.import_type == "deep"
                item1['key'] = 'created_at'
                item1['value'] = [{'key' => 'from', 'value' => (Time.now - (import_item.days.days rescue 1.days)).utc.to_s}]
              elsif credential.last_imported_at.to_s != ""
                item1['key'] = 'created_at'
                item1['value'] = [{'key' => 'from', 'value' => credential.last_imported_at.to_s}]
              end       
              if item1.present?
                @filter1['item'] = item1
                @filters1['complex_filter'] = @filter1
                @filters_array = @filters_array.merge(@filters1)
              end
              @filters_array
            end

            def get_orders(client, credential, session, import_item)
              orders = []
              statuses = get_statuses_to_import(credential)
              statuses.each do |status|
                filters_array = get_filters(status, credential, import_item)
                response = client.call(:sales_order_list, message: {sessionId: session, filters: filters_array})
                next if response.body[:sales_order_list_response][:result][:item].blank?
                orders << response.body[:sales_order_list_response][:result][:item]
              end
              orders.flatten
            end

            def import_single_order(item, import_item, client, credential, session, result)
              import_item.current_increment_id = item[:increment_id]
              import_item.current_order_items = -1
              import_item.current_order_imported_item = -1
              import_item.save
              attempts = 0
              loop do
                begin
                  order_info = client.call(:sales_order_info, message: {sessionId: session, orderIncrementId: item[:increment_id]})
                rescue Exception => ex
                  attempts = attempts + 1
                end
                break if attempts >= 5
              end
              order_info = order_info.body[:sales_order_info_response][:result]
              if Order.where(:increment_id => item[:increment_id]).length == 0
                @order = Order.new
                @order.increment_id = item[:increment_id]
                @order.store_order_id = order_info[:order_id]
                @order.status = 'awaiting'
                @order.order_placed_time = item[:created_at]
                #@order.storename = item[:store_name]
                @order.store = credential.store
                line_items = order_info[:items]
                if line_items[:item].is_a?(Hash)
                  import_item.current_order_items = 1
                  import_item.current_order_imported_item = 0
                  import_item.save
                  product_id = nil
                  
                  if line_items[:item][:product_type] != 'configurable'
                    
                    @order_item = OrderItem.new
                    @order_item.price = line_items[:item][:price]
                    @order_item.qty = line_items[:item][:qty_ordered]
                    @order_item.row_total= line_items[:item][:row_total]
                    @order_item.name = line_items[:item][:name] || "Un-named Magento Product"
                    @order_item.sku = line_items[:item][:sku]
                    if ProductSku.where(:sku => @order_item.sku).length == 0
                      #import other product details
                      product_id = Groovepacker::Stores::Importers::Magento::
                          ProductsImporter.new(handler).import_single({ product_id: line_items[:item][:product_id] })
                    else
                      product_id = ProductSku.where(:sku => @order_item.sku).first.product_id
                    end
                    @order_item.product_id = product_id
                    @order.order_items << @order_item
                  else
                    if ProductSku.where(:sku => line_items[:item][:sku]).length == 0
                      Groovepacker::Stores::Importers::Magento::
                          ProductsImporter.new(handler).import_single({ product_id: line_items[:item][:product_id] })
                    end
                  end
                  
                  import_item.current_order_imported_item = 1
                  import_item.save
                else
                  import_item.current_order_items = line_items[:item].length
                  import_item.current_order_imported_item = 0
                  import_item.save
                  line_items[:item].each do |line_item|
                    if line_item[:product_type] != 'configurable'
                      @order_item = OrderItem.new
                      @order_item.price = line_item[:price]
                      @order_item.qty = line_item[:qty_ordered]
                      @order_item.row_total= line_item[:row_total]
                      @order_item.name = line_item[:name] || "Un-named Magento Product"
                      @order_item.sku = line_item[:sku]
                      if ProductSku.where(:sku => @order_item.sku).length == 0
                        product_id = Groovepacker::Stores::Importers::Magento::
                            ProductsImporter.new(handler).import_single({ product_id: line_item[:product_id] })
                      else
                        product_id = ProductSku.where(:sku => @order_item.sku).first.product_id
                      end
                      @order_item.product_id = product_id
                      @order.order_items << @order_item
                    else
                      if ProductSku.where(:sku => line_item[:sku]).length == 0
                        Groovepacker::Stores::Importers::Magento::
                            ProductsImporter.new(handler).import_single({ product_id: line_item[:product_id] })
                      end
                    end
                    import_item.current_order_imported_item = import_item.current_order_imported_item + 1
                    import_item.save
                  end
                end

                #if product does not exist import product using product.info
                @order.address_1 = order_info[:shipping_address][:street]
                @order.city = order_info[:shipping_address][:city]
                @order.country = order_info[:shipping_address][:country_id]
                @order.postcode = order_info[:shipping_address][:postcode]
                @order.email = item[:customer_email]
                @order.lastname = order_info[:shipping_address][:lastname]
                @order.firstname = order_info[:shipping_address][:firstname]
                @order.state = order_info[:shipping_address][:region]
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
      end
    end
  end
end
