# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      module Shipworks
        include ProductsHelper
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          def import_order(order)
            sw_start_time = Time.current
            @worker_id = 'worker_' + SecureRandom.hex
            handler = get_handler
            credential = handler[:credential]
            store = handler[:store_handle]
            import_item = handler[:import_item]
            # order["OnlineStatus"] == 'Processing'
            if import_item.status != 'cancelled'
              order_number = get_order_number(order, credential)
              if credential.can_import_an_order?
                if allowed_status_to_import?(credential, order['Status'])
                  if Order.find_by_increment_id(order_number).nil?
                    import_item.current_increment_id = order_number
                    import_item.save
                    ship_address = get_ship_address(order)
                    tracking_num = nil
                    tracking_num = order['Shipment']['TrackingNumber'] if order['Shipment'].class.to_s.include?('Hash')
                    notes_internal = get_internal_notes(order) unless order['Note'].nil?

                    Order.transaction do
                      order_m = Order.new(
                        increment_id: order_number,
                        order_placed_time: order['Date'],
                        store: store,
                        email: ship_address['Email'],
                        lastname: ship_address['LastName'],
                        firstname: ship_address['FirstName'],
                        address_1: ship_address['Line1'],
                        address_2: ship_address['Line2'],
                        city: ship_address['City'],
                        state: ship_address['StateName'],
                        postcode: ship_address['PostalCode'],
                        country: ship_address['CountryCode'],
                        order_total: order['Total'],
                        tracking_num: tracking_num,
                        notes_internal: notes_internal,
                        custom_field_one: order['CustomField1'],
                        custom_field_two: order['CustomField2'],
                        importer_id: @worker_id
                      )
                      import_item.current_order_items = begin
                                                          order['Item'].length
                                                        rescue StandardError
                                                          0
                                                        end
                      import_item.current_order_imported_item = 0
                      import_item.save

                      if order_m.save
                        if order['Item'].is_a? Array
                          order['Item'].each do |item|
                            import_order_item(item, import_item, order_m, store)
                          end
                        else
                          import_order_item(order['Item'], import_item, order_m, store)
                        end
                      end

                      order_m.set_order_status
                      import_item.success_imported = 1
                      import_item.save

                      order_m.addactivity('Order Import', store.name + ' Import')
                      order_m.order_items.each do |item|
                        unless item.product.nil? || item.product.primary_sku.nil?
                          order_m.addactivity('Item with SKU: ' + item.product.primary_sku + ' Added', store.name + ' Import')
                        end
                      end
                    end
                    import_item.status = 'completed'
                    import_item.save
                  else
                    import_item.status = 'failed'
                    import_item.message = 'No new orders with the currently enabled statuses.'
                    import_item.save
                  end
                else
                  import_item.status = 'failed'
                  import_item.message = 'No incoming orders with the currently enabled statuses.'
                  import_item.save
                end
              else
                import_item.status = 'failed'
                import_item.message = 'No incoming orders with the currently enabled statuses.'
                import_item.save
              end
            end
            updated_products = Product.where(status_updated: true)
            if updated_products.any?
              orders_count = Order.joins(:order_items).where('order_items.product_id IN (?)', updated_products.map(&:id)).count
              if orders_count.positive?
                action = GrooveBulkActions.where(identifier: 'order', activity: 'status_update', status: 'pending').first
                action = GrooveBulkActions.new(identifier: 'order', activity: 'status_update', status: 'pending') if action.blank?
                action.total = orders_count
                action.save
              end
              # (orders||[]).find_each(:batch_size => 100) do |order|
              #   order.update_order_status
              # end
            end
            # update_orders_status
            sw_end_time = "#{(Time.current - sw_start_time).round(2)} Seconds"
            log_sw_tenants = %w[pinehurstcoins gp55 gp50 ftdi ftdi2]
            if Apartment::Tenant.current.in? log_sw_tenants
              on_demand_logger = Logger.new("#{Rails.root}/log/sw_delay_logs.log")
              log = { tenant: Apartment::Tenant.current, order_number: (begin
                                                                          order_number
                                                                        rescue StandardError
                                                                          nil
                                                                        end), import_time: sw_end_time, current_time: Time.current.to_formatted_s(:rfc822) }
              on_demand_logger.info(log)
            end
          rescue StandardError => e
            begin
              log_import_error(e)
            rescue StandardError
              nil
            end
            begin
              import_item.update(success_imported: import_item.success_imported + 1)
            rescue StandardError
              nil
            end
          end

          private

          def allowed_status_to_import?(credential, status)
            return true if credential.shall_import_ignore_local
            return false if status.nil? && !credential.shall_import_no_status
            return true if status.nil? && credential.shall_import_no_status
            return true if status.strip == 'In Process' && credential.shall_import_in_process
            return true if status.strip == 'New Order' && credential.shall_import_new_order
            return true if status.strip == 'Not Shipped' && credential.shall_import_not_shipped
            return true if status.strip == 'Shipped' && credential.shall_import_shipped

            false
          end

          def get_order_number(order, credential)
            if credential.import_store_order_number && !order['Amazon'].nil?
              order['Amazon']['AmazonOrderID']
            else
              order['Number']
            end
          end

          def get_ship_address(order)
            result = nil

            order['Address'].each do |addr|
              if addr['type'] == 'ship'
                result = addr
                break
              end
            end

            result
          end

          def get_internal_notes(order)
            internal_notes = nil
            # if order["Note"] is array or hash
            if order['Note'].is_a?(Array)
              notes = []
              order['Note'].each do |note|
                notes << note['Text'] if note['Visibility'] == 'Internal'
              end
              internal_notes = notes.join(' || ')
            else
              internal_notes = order['Note']['Text'] if order['Note']['Visibility'] == 'Internal'
            end
            internal_notes
          end

          def import_order_item(item, import_item, order, store)
            sku = nil
            if item.present?
              if item['SKU'].present?
                sku = item['SKU']
              else
                sku = item['Code'] if item['Code'].present? && item['Code'] != item['SKU']
              end
            end
            sku = sku.try(:strip)
            product = if !sku.nil? && ProductSku.find_by_sku(sku)
                        ProductSku.find_by_sku(sku).product
                      else
                        begin
                          import_product(item, store)
                        rescue StandardError
                          nil
                        end
                      end
            if item.present?
              order_item = order.order_items.find_by(product_id: product.id) 
              order_item ? order_item.update(qty: order_item.qty + item['Quantity'].to_i) : order.order_items.create!( product: product, price: item['UnitPrice'].to_f, qty: item['Quantity'], row_total: item['TotalPrice'])
          end
            import_item.current_order_imported_item = import_item.current_order_imported_item + 1
            import_item.save
            # make_product_intangible(product)
          end

          def import_product(item, store)
            item_name = item['Name'].blank? ? 'Product Created by Shipworks Import' : item['Name']
            product = Product.create(
              store: store,
              name: item_name,
              weight: item['Weight'],
              store_product_id: item['ID']
            )
            product.add_product_activity('Product Import', product.store.try(:name).to_s)
            found_sku = false
            # SKU
            unless item['SKU'].nil?
              product.product_skus.create(sku: item['SKU'])
              found_sku = true
            end
            unless item['Code'].nil? || item['Code'] == item['SKU']
              product.product_skus.create(sku: item['Code'])
              found_sku = true
            end

            product.product_skus.create(sku: ProductSku.get_temp_sku) unless found_sku

            # Barcodes
            if item['UPC'].present?
              product.product_barcodes.create(
                barcode: item['UPC']
              )
            elsif store.shipworks_credential.gen_barcode_from_sku && item['SKU'].present? && ProductBarcode.where(barcode: item['SKU']).empty?
              product.product_barcodes.create(
                barcode: item['SKU']
              )
            end

            # Images
            unless item['Image'].nil?
              product.product_images.create(
                image: item['Image']
              )
            end

            # Location
            unless item['Location'].nil?
              inv_wh = ProductInventoryWarehouses.find_or_create_by(product_id: product.id, inventory_warehouse_id: store.inventory_warehouse_id)
              inv_wh.location_primary = item['Location']
              inv_wh.save
            end

            product.set_product_status
            product
          end
        end
      end
    end
  end
end

# # temporary method for importing shipworks
#  def import_shipworks
#    shipworks = params["ShipWorks"]
#    order = Order.new

#    order.increment_id = shipworks["Order"]["Number"]
#    order.
#  end
