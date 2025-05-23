# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      module Ebay
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          def import
            handler = get_handler
            credential = handler[:credential]
            ebay = handler[:store_handle]
            import_item = handler[:import_item]
            result = build_result
            begin
              if credential.shipped_status && credential.unshipped_status
                begin
                  awaiting = ebay.GetMyeBaySelling(soldList: { orderStatusFilter: 'AwaitingShipment' })
                  shipped = ebay.GetMyeBaySelling(soldList: { orderStatusFilter: 'PaidAndShipped' })
                  shipped.soldList.orderTransactionArray = shipped.soldList.orderTransactionArray.push(awaiting.soldList.orderTransactionArray).flatten
                  seller_list = shipped
                rescue StandardError
                  seller_list = ebay.GetMyeBaySelling(soldList: { orderStatusFilter: 'AwaitingShipment' })
                end
              elsif credential.shipped_status
                seller_list = ebay.GetMyeBaySelling(soldList: { orderStatusFilter: 'PaidAndShipped' })
              else
                seller_list = ebay.GetMyeBaySelling(soldList: { orderStatusFilter: 'AwaitingShipment' })
              end
              if !seller_list.soldList.nil? &&
                 !seller_list.soldList.orderTransactionArray.nil?
                order_or_transactionArray =
                  seller_list.soldList.orderTransactionArray

                result[:total_imported] =
                  seller_list.soldList.orderTransactionArray.length
                import_item.current_increment_id = ''
                import_item.success_imported = 0
                import_item.previous_imported = 0
                import_item.current_order_items = -1
                import_item.current_order_imported_item = -1
                import_item.to_import = result[:total_imported]
                import_item.save
                @ordercnt = 0

                order_or_transactionArray.each do |order_transaction|
                  import_item = fix_import_item(import_item)
                  break if import_item.status == 'cancelled'

                  # single line item order transaction
                  if !order_transaction.transaction.nil?
                    transactionID = order_transaction.transaction.transactionID
                    itemID = order_transaction.transaction.item.itemID

                    # get sellingmanager SalesRecordNumber
                    item_transactions = ebay.GetItemTransactions(itemID: itemID,
                                                                 transactionID: transactionID, includeContainingOrder: true)
                    if item_transactions.transactionArray.length == 1
                      transaction = item_transactions.transactionArray.first
                      sellingManagerSalesRecordNumber =
                        transaction.shippingDetails.sellingManagerSalesRecordNumber
                      order_id_ebay = transaction.containingOrder.try(:orderID)
                      order_id_ebay ||= sellingManagerSalesRecordNumber
                      # import_item.current_increment_id = sellingManagerSalesRecordNumber
                      import_item.current_increment_id = order_id_ebay
                      import_item.current_order_items = -1
                      import_item.current_order_imported_item = -1
                      import_item.save
                      if Order.where(increment_id: order_id_ebay).empty?
                        order = Order.new

                        order = build_order_with_single_item_from_ebay(order, transaction,
                                                                       order_transaction, handler)
                        if order.save
                          order.addactivity('Order Import', "#{credential.store.name} Import")
                          order.order_items.each do |item|
                            order.addactivity("Item with SKU: #{item.sku} Added", "#{credential.store.name} Import")
                          end
                          order.set_order_status
                          result[:success_imported] = result[:success_imported] + 1
                          import_item.success_imported = result[:success_imported]
                          import_item.save
                        end
                      else # transaction is already imported
                        result[:previous_imported] = result[:previous_imported] + 1
                        import_item.previous_imported = result[:previous_imported]
                        import_item.save
                      end
                    else # transactions Array is not equal to 1
                      result[:status] &= false
                      result[:messages].push("There was an error importing the order transactions from Ebay,
                        Order transactions length: #{item_transactions.transactionArray.length}")
                    end
                  elsif !order_transaction.order.nil?
                    # for orders with multiple line items
                    order_id = order_transaction.order.orderID
                    order_detail = ebay.GetOrders(orderIDArray: [order_id])

                    if !order_detail.orderArray.nil? &&
                       order_detail.orderArray.length == 1

                      order_detail = order_detail.orderArray.first

                      sellingManagerSalesRecordNumber = order_detail.shippingDetails&.sellingManagerSalesRecordNumber
                      # import_item.current_increment_id = sellingManagerSalesRecordNumber
                      import_item.current_increment_id = order_id
                      import_item.current_order_items = -1
                      import_item.current_order_imported_item = -1
                      import_item.save
                      if Order.where(increment_id: order_id).empty?
                        order = Order.new
                        order = build_order_with_multiple_items_from_ebay(order, order_detail, handler, order_id)
                        if order.save
                          order.addactivity('Order Import', "#{credential.store.name} Import")
                          order.order_items.each do |item|
                            order.addactivity("Item with SKU: #{item.sku} Added", "#{credential.store.name} Import")
                          end
                          order.set_order_status
                          result[:success_imported] = result[:success_imported] + 1
                          import_item.success_imported = result[:success_imported]
                          import_item.save
                        end
                      else # order is already imported
                        result[:previous_imported] = result[:previous_imported] + 1
                        import_item.previous_imported = result[:previous_imported]
                        import_item.save
                      end
                    else
                      # order detail cannot be more than 1
                      result[:status] &= false
                      result[:messages].push('More than 1 order detail is returned for a single order id')
                    end
                  else
                    result[:status] &= false
                    result[:messages].push('Importing orders with multiple order items is not supported')
                  end
                end # end of order transaction array
              end # end of sellers list's sold list
            rescue Exception => e
              result[:status] &= false
              result[:messages].push(e.message)
              import_item.message = e.message
              import_item.save
            end
            result
          end

          def import_single(_hash)
            {}
          end

          private

          def build_order_with_single_item_from_ebay(order, transaction,
                                                     order_transaction, handler)
            credential = handler[:credential]
            ebay = handler[:store_handle]
            import_item = handler[:import_item]

            order.status = 'awaiting'
            order.store = credential.store
            # order.increment_id = transaction.shippingDetails.sellingManagerSalesRecordNumber
            order.increment_id = transaction.containingOrder.try(:orderID) || transaction.shippingDetails.sellingManagerSalesRecordNumber
            order.order_placed_time = transaction.createdDate

            if !transaction.buyer.nil? && !transaction.buyer.buyerInfo.nil? &&
               !transaction.buyer.buyerInfo.shippingAddress.nil?
              order.address_1 = transaction.buyer.buyerInfo.shippingAddress.street1
              order.city = transaction.buyer.buyerInfo.shippingAddress.cityName
              order.state = transaction.buyer.buyerInfo.shippingAddress.stateOrProvince
              order.country = transaction.buyer.buyerInfo.shippingAddress.country
              order.postcode = transaction.buyer.buyerInfo.shippingAddress.postalCode
              # split name separated by a space
              unless transaction.buyer.buyerInfo.shippingAddress.name.nil?
                split_name = transaction.buyer.buyerInfo.shippingAddress.name.split(' ')
                order.lastname = split_name.pop
                order.firstname = split_name.join(' ')
              end
            end
            import_item.current_order_items = 1
            import_item.current_order_imported_item = 0
            import_item.save
            # single item transaction does not have transaction array
            order_item = OrderItem.new
            order_item.price = transaction.transactionPrice
            order_item.qty = transaction.quantityPurchased
            order_item.row_total = transaction.amountPaid
            order_item.sku = order_transaction.transaction.item.sKU
            # create product if it does not exist already
            order_item.product_id =
              Groovepacker::Stores::Importers::Ebay::
                  ProductsImporter.new(handler).import_single(
                    itemID: order_transaction.transaction.item.itemID,
                    sku: order_transaction.transaction.item.sKU,
                    ebay: ebay,
                    credential: credential
                  )
            order.order_items << order_item
            import_item.current_order_imported_item = 1
            import_item.save
            order
          end

          def build_order_with_multiple_items_from_ebay(order, order_detail, handler, order_id = nil)
            credential = handler[:credential]
            ebay = handler[:store_handle]
            import_item = handler[:import_item]
            order.status = 'awaiting'
            order.store = credential.store
            # order.increment_id = order_detail.shippingDetails.sellingManagerSalesRecordNumber
            order.increment_id = order_id
            order.order_placed_time = order_detail.createdTime

            unless order_detail.shippingAddress.nil?
              order.address_1 = order_detail.shippingAddress.street1
              order.city = order_detail.shippingAddress.cityName
              order.state = order_detail.shippingAddress.stateOrProvince
              order.country = order_detail.shippingAddress.country
              order.postcode = order_detail.shippingAddress.postalCode
              # split name separated by a space
              unless order_detail.shippingAddress.name.nil?
                split_name = order_detail.shippingAddress.name.split(' ')
                order.lastname = split_name.pop
                order.firstname = split_name.join(' ')
              end
            end
            import_item.current_order_items = order_detail.transactionArray.length
            import_item.current_order_imported_item = 0
            import_item.save
            # multiple order items from transaction array
            order_detail.transactionArray.each do |transaction|
              order_item = OrderItem.new
              order_item.price = transaction.transactionPrice
              order_item.qty = transaction.quantityPurchased
              order_item.row_total = transaction.amountPaid
              order_item.sku = transaction.item.sKU
              # create product if it does not exist already
              order_item.product_id =
                Groovepacker::Stores::Importers::Ebay::
                    ProductsImporter.new(handler).import_single(
                      itemID: transaction.item.itemID,
                      sku: transaction.item.sKU,
                      ebay: ebay,
                      credential: credential
                    )
              order.order_items << order_item
              import_item.current_order_imported_item = import_item.current_order_imported_item + 1
              import_item.save
            end

            order
          end
        end
      end
    end
  end
end
