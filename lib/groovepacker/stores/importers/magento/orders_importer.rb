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
            @filters_array = {}
            @filters = {}
            @filter = {}
            item = {}
            item['key'] = 'status'
            item['value'] = 'processing'
            @filter['item'] = item
            @filters['filter'] = @filter
            @filters_array = @filters

            @filters1 = {}
            @filter1 = {}
            item1 = {}
            if credential.last_imported_at.to_s != ""
              item1['key'] = 'created_at'
              item1['value'] = [{'key' => 'from', 'value' => credential.last_imported_at.to_s}]
              @filter1['item'] = item1
              @filters1['complex_filter'] = @filter1
              @filters_array = @filters_array.merge(@filters1)
            end
            credential.last_imported_at = DateTime.now
            credential.save
            begin
              response = client.call(:sales_order_list, message:
                                                        {sessionId: session, filters: @filters_array})

              if response.success?
                if !response.body[:sales_order_list_response][:result][:item].nil?
                  result[:total_imported] = response.body[:sales_order_list_response][:result][:item].length
                  import_item.current_increment_id = ''
                  import_item.success_imported = 0
                  import_item.previous_imported = 0
                  import_item.current_order_items = -1
                  import_item.current_order_imported_item = -1
                  import_item.to_import = result[:total_imported]
                  import_item.save

                  response.body[:sales_order_list_response][:result][:item].each do |item|
                    import_item.current_increment_id = item[:increment_id]
                    import_item.current_order_items = -1
                    import_item.current_order_imported_item = -1
                    import_item.save
                    order_info = client.call(:sales_order_info,
                                             message: {sessionId: session, orderIncrementId: item[:increment_id]})

                    order_info = order_info.body[:sales_order_info_response][:result]
                    if Order.where(:increment_id => item[:increment_id]).length == 0
                      @order = Order.new
                      @order.increment_id = item[:increment_id]
                      @order.status = 'awaiting'
                      @order.order_placed_time = item[:created_at]
                      #@order.storename = item[:store_name]
                      @order.store = credential.store
                      line_items = order_info[:items]
                      if line_items[:item].is_a?(Hash)
                        import_item.current_order_items = 1
                        import_item.current_order_imported_item = 0
                        import_item.save
                        if line_items[:item][:product_type] == 'simple'
                          @order_item = OrderItem.new
                          @order_item.price = line_items[:item][:price]
                          @order_item.qty = line_items[:item][:qty_ordered]
                          @order_item.row_total= line_items[:item][:row_total]
                          @order_item.name = line_items[:item][:name]
                          @order_item.sku = line_items[:item][:sku]
                          if ProductSku.where(:sku => @order_item.sku).length == 0
                            #import other product details
                            product_id = Groovepacker::Stores::Importers::Magento::
                                ProductsImporter.new(handler).import_single({
                                                                              sku: @order_item.sku})
                          else
                            product_id = ProductSku.where(:sku => @order_item.sku).first.product_id
                          end
                          @order_item.product_id = product_id
                          @order.order_items << @order_item
                        else
                          if ProductSku.where(:sku => line_items[:item][:sku]).length == 0
                            Groovepacker::Stores::Importers::Magento::
                                ProductsImporter.new(handler).import_single({
                                                                              sku: line_items[:item][:sku]})
                          end
                        end
                        import_item.current_order_imported_item = 1
                        import_item.save
                      else
                        import_item.current_order_items = line_items[:item].length
                        import_item.current_order_imported_item = 0
                        import_item.save
                        line_items[:item].each do |line_item|
                          if line_item[:product_type] == 'simple'
                            @order_item = OrderItem.new
                            @order_item.price = line_item[:price]
                            @order_item.qty = line_item[:qty_ordered]
                            @order_item.row_total= line_item[:row_total]
                            @order_item.name = line_item[:name]
                            @order_item.sku = line_item[:sku]

                            if ProductSku.where(:sku => @order_item.sku).length == 0
                              product_id = Groovepacker::Stores::Importers::Magento::
                                  ProductsImporter.new(handler).import_single({
                                                                                sku: @order_item.sku})
                            else
                              product_id = ProductSku.where(:sku => @order_item.sku).first.product_id
                            end
                            @order_item.product_id = product_id
                            @order.order_items << @order_item
                          else
                            if ProductSku.where(:sku => line_item[:sku]).length == 0
                              Groovepacker::Stores::Importers::Magento::
                                  ProductsImporter.new(handler).import_single({
                                                                                sku: line_item[:sku]})
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
              else

              end
            rescue Exception => e
              result[:status] &= false
              result[:messages].push(e.message)
              import_item.message = e.message
              import_item.save
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
