# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      module ShippingEasy
        class OrdersImporter < Groovepacker::Stores::Importers::Importer
          include Groovepacker::Stores::Importers::ShippingEasy::ProductsImporter
          include ShippingEasyHelper

          def import
            init_common_objects
            return @result if import_statuses_are_empty

            importing_time = Time.current
            begin
              OrderImportSummary.top_summary.emit_data_to_user(true)
            rescue StandardError
              nil
            end
            return @result unless @import_item.present?

            @import_item.update_column(:importer_id, @worker_id)
            update_import_summary_to_fetch_api_response
            response = @client.orders(@statuses, importing_time, @import_item)
            update_import_summary_to_in_progress
            update_error_msg_if_any(response)
            destroy_cleared_orders(response)
            return @result if response['orders'].nil?

            @regular_import = true
            Groovepacker::Stores::Importers::LogglyLog.log_orders_response(response['orders'], @import_item.store, @import_item) if current_tenant_object&.loggly_se_imports

            import_orders_from_response(response, importing_time)
            # @result[:total_imported] = response["orders"].uniq.length
            # update_import_item_obj_values
            # uniq_response = response["orders"].uniq rescue []
            # verify_separately = @import_item.store.split_order == "verify_separately" ? true : false
            # if @import_item.store.split_order == "verify_separately" || @import_item.store.split_order == "verify_together"
            #   @split_order = true
            # else
            #   @split_order = false
            # end
            # if @split_order
            #   @group_orders = uniq_response.group_by { |d| d["external_order_identifier"]}
            #   uniq_response = @group_orders unless verify_separately
            #   uniq_response = uniq_response.values unless verify_separately
            # end
            # uniq_response.each do |orders|
            #   if @split_order && !verify_separately && orders.count > 1
            #     orders.each_with_index do |odr, index|
            #       unless index == 0
            #         if orders.first["recipients"].first["original_order"]["store_id"] == odr["recipients"].first["original_order"]["store_id"]
            #           orders.first["recipients"].first["line_items"] << odr["recipients"].first["line_items"]
            #           orders.first["recipients"].first["line_items"].flatten!
            #           # orders.first["shipments"] << odr["shipments"]
            #           # orders.first["shipments"].flatten!
            #         end
            #       end
            #     end
            #   end
            #   if @split_order
            #     order_copy = verify_separately ? orders : orders.first
            #   else
            #     order_copy = orders
            #   end
            #   order = order_copy unless order_copy.blank?
            #   @order_to_update = false
            #   import_item_fix
            #   break if @import_item.status == 'cancelled'
            #   import_single_order(order)
            #   #increase_import_count
            #   sleep 0.5
            # end

            # @credential.update(last_imported_at: importing_time) if @result[:status] && @import_item.status != 'cancelled'
            # update_orders_status
            # unless  @credential.allow_duplicate_id
            #   a = Order.group(:increment_id).having("count(*) >1").count.keys
            #   unless a.empty?
            #     Order.where("increment_id in (?)", a).each do |o|
            #       orders = Order.where(increment_id: o.increment_id)
            #       orders.last.destroy if orders.count > 1
            #     end
            #   end
            # end
            @result
          end

          # def ondemand_import_single_order(order)
          #   init_common_objects
          #   response = @client.get_single_order(order)
          #   import_single_order(response["orders"][0]) rescue nil
          # end

          def range_import(start_date, end_date, type, user_id)
            init_common_objects
            if type == 'created'
              start_date = convert_time_from_gp(Time.zone.parse(start_date).utc)
              end_date = convert_time_from_gp(Time.zone.parse(end_date).utc)
              extract_field = 'ordered_at'
            else
              start_date = Time.zone.parse(start_date).strftime('%Y-%m-%d %H:%M:%S')
              end_date = Time.zone.parse(end_date).strftime('%Y-%m-%d %H:%M:%S')
              extract_field = 'updated_at'
            end
            init_order_import_summary(user_id)
            importing_time = Time.zone.now
            response = @client.orders(@statuses, importing_time, @import_item, Time.zone.parse(start_date))
            response['orders'] = begin
                                   response['orders'].sort_by { |h| Time.zone.parse(h['updated_at']) }
                                 rescue StandardError
                                   response['orders']
                                 end
            response['orders'] = response['orders'].select { |h| Time.zone.parse(h[extract_field]) <= Time.zone.parse(end_date) }
            update_error_msg_if_any(response)
            destroy_cleared_orders(response)
            emit_data_for_range_or_quickfix(response['orders'].count)
            import_orders_from_response(response, importing_time)
            update_order_import_summary
          end

          def quick_fix_import(import_date, order_id, user_id)
            init_common_objects
            import_date = Time.zone.parse(import_date) + Time.zone.utc_offset
            import_date = DateTime.parse(import_date.to_s)
            quick_fix_range = get_quick_fix_range(import_date, order_id)
            init_order_import_summary(user_id)
            importing_time = Time.zone.now
            response = @client.orders(@statuses, importing_time, @import_item, quick_fix_range[:start_date])
            response['orders'] = begin
                                   response['orders'].sort_by { |h| Time.zone.parse(h['updated_at']) }
                                 rescue StandardError
                                   response['orders']
                                 end
            response['orders'] = response['orders'].select { |h| Time.zone.parse(h['updated_at']) <= quick_fix_range[:end_date] }
            update_error_msg_if_any(response)
            destroy_cleared_orders(response)
            emit_data_for_range_or_quickfix(response['orders'].count)
            import_orders_from_response(response, importing_time)
            update_order_import_summary
          end

          private

          def import_orders_from_response(response, _importing_time)
            @result[:total_imported] = response['orders'].uniq.length
            update_import_item_obj_values
            uniq_response = begin
                                response['orders'].uniq
                            rescue StandardError
                              []
                              end
            verify_separately = (@import_item.store.split_order.in? %w[shipment_handling_v2 verify_separately]) ? true : false
            @split_order = if @import_item.store.split_order.in? %w[shipment_handling_v2 verify_separately verify_together]
                             true
                           else
                             false
                           end
            if @split_order
              @group_orders = uniq_response.group_by { |d| d['external_order_identifier'] }
              uniq_response = @group_orders unless verify_separately
              uniq_response = uniq_response.values unless verify_separately
            end
            uniq_response.each do |orders|
              if @split_order && !verify_separately && orders.count > 1
                orders.each_with_index do |odr, index|
                  next if index == 0
                  next unless orders.first['recipients'].first['original_order']['store_id'] == odr['recipients'].first['original_order']['store_id']

                  orders.first['recipients'].first['line_items'] << odr['recipients'].first['line_items']
                  orders.first['recipients'].first['line_items'].flatten!
                  # orders.first["shipments"] << odr["shipments"]
                  # orders.first["shipments"].flatten!
                end
              end
              order_copy = if @split_order
                             verify_separately ? orders : orders.first
                           else
                             orders
                           end
              order = order_copy unless order_copy.blank?
              @order_to_update = false
              import_item_fix
              ImportItem.where(store_id: @import_item.store.id).where.not(id: @import_item.id).where.not(status: %w[failed completed]).order(:created_at).drop(1).each { |item| item.update_column(:status, 'cancelled') }

              break if import_should_be_cancelled
              import_single_order(order)
              # increase_import_count
              # sleep 0.5
            end

            # @credential.update(last_imported_at: importing_time) if @result[:status] && @import_item.status != 'cancelled'
            # update_orders_status
            Tenant.save_se_import_data('==ImportItem', @import_item.as_json, '==OrderImportSumary', @import_item.try(:order_import_summary).try(:as_json))
            unless @credential.allow_duplicate_id
              a = Order.group(:increment_id).having('count(*) >1').count.keys
              unless a.empty?
                Order.where('increment_id in (?)', a).each do |o|
                  orders = Order.where(increment_id: o.increment_id)
                  orders.last.destroy if orders.count > 1
                end
              end
            end
          end

          def import_single_order(order)
            return if skip_the_order?(order)

            update_current_import_item(order)
            @org_ext_identifier = order['external_order_identifier']
            @ext_identifier = get_ext_identifier(order)
            return if check_order_is_cancelled(order)
            if @split_order ||= @import_item.store.split_order.in?(%w[shipment_handling_v2 verify_separately verify_together])
              if order['shipments'].any?
                if order['shipments'].count == 1
                  shiping_easy_order = Order.find_by_store_order_id(order['id'])
                  if shiping_easy_order.blank?
                    shiping_easy_order = begin
                                              Order.find_by_shipment_id(order['shipments'][0]['id'])
                                         rescue StandardError
                                           nil
                                            end
                  else
                    shiping_easy_order
                  end
                elsif order['shipments'].count >= 2
                  order['shipments'].each do |shipment|
                    shiping_easy_order = begin
                                             Order.find_by_shipment_id(shipment['id'])
                                         rescue StandardError
                                           nil
                                           end
                    next unless shiping_easy_order.blank?

                    @shipment_value = shipment['id']
                    @tracking_value = shipment['tracking_number']
                    @cloned_shipment_id = shipment['cloned_from_shipment_id']
                    break
                  end
                end
              else
                shiping_easy_order = find_shipping_easy_order(order)
                if shiping_easy_order && @group_orders && (@import_item.store.split_order.in? %w[shipment_handling_v2 verify_separately])
                  g_orders = Marshal.load(Marshal.dump(@group_orders[order['external_order_identifier']]))
                  g_orders.each_with_index do |odr, index|
                    next if index == 0
                    next unless g_orders.first['recipients'].first['original_order']['store_id'] == odr['recipients'].first['original_order']['store_id']

                    g_orders.first['recipients'].first['line_items'] << odr['recipients'].first['line_items']
                    g_orders.first['recipients'].first['line_items'].flatten!
                  end
                  order = g_orders.first
                end
              end
              if shiping_easy_order.blank?
                if @import_item.store.split_order == 'shipment_handling_v2'
                  order = check_prev_splitted_order(order)
                else
                  shiping_easy_order = Order.where('increment_id LIKE ?', "#{@ext_identifier.strip}%")
                  # unless @credential.allow_duplicate_id
                  order['external_order_identifier'] = "#{@ext_identifier}-#{shiping_easy_order.count}" if shiping_easy_order.count > 0
                  # end
                end
                shiping_easy_order = Order.new
              else
                # return if shiping_easy_order.persisted? and shiping_easy_order.status=="scanned" || (shiping_easy_order.order_items.map(&:scanned_status).include?("scanned") ||
                # shiping_easy_order.order_items.map(&:scanned_status).include?("partially_scanned"))
                update_success_import_count && return if not_to_update(shiping_easy_order, order)
                order['external_order_identifier'] = shiping_easy_order.increment_id
              end
            else
              update_success_import_count && return if Order.where(store_order_id: order['id'], prime_order_id: order['prime_order_id'], last_modified: order['updated_at'].to_datetime).any?
              shiping_easy_order = find_shipping_easy_order(order)
              shiping_easy_order = Order.new if shiping_easy_order.blank?
              # return if shiping_easy_order.persisted? and shiping_easy_order.status=="scanned" || (shiping_easy_order.order_items.map(&:scanned_status).include?("scanned") ||
              #   shiping_easy_order.order_items.map(&:scanned_status).include?("partially_scanned"))
              update_success_import_count && return if not_to_update(shiping_easy_order, order)
            end
            @order_to_update = true if shiping_easy_order.persisted?
            shiping_easy_order.order_items.destroy_all
            shiping_easy_order.store_id = @credential.store_id
            import_order(shiping_easy_order, order)
            if order['shipments'].count == 1
              shiping_easy_order.shipment_id = begin
                                                   order['shipments'][0]['id']
                                               rescue StandardError
                                                 nil
                                                 end
              shiping_easy_order.tracking_num = begin
                                                    order['shipments'][0]['tracking_number']
                                                rescue StandardError
                                                  nil
                                                  end
              shiping_easy_order.cloned_from_shipment_id = begin
                                                               order['shipments'][0]['cloned_from_shipment_id']
                                                           rescue StandardError
                                                             nil
                                                             end
            elsif order['shipments'].count >= 2
              shiping_easy_order.shipment_id = begin
                                                   @shipment_value
                                               rescue StandardError
                                                 nil
                                                 end
              shiping_easy_order.tracking_num = begin
                                                    @tracking_value
                                                rescue StandardError
                                                  nil
                                                  end
              shiping_easy_order.cloned_from_shipment_id = begin
                                                               @cloned_shipment_id
                                                           rescue StandardError
                                                             nil
                                                             end
            end
            import_order_items_and_create_products(shiping_easy_order, order)
            update_success_import_count
            update_multi_shipment_status(shiping_easy_order.prime_order_id)
            add_split_combined_activity(order, shiping_easy_order)
            @credential.update(last_imported_at: Time.zone.parse(order['updated_at'])) if @import_item.status != 'cancelled' && @regular_import
          rescue StandardError => e
            begin
                log_import_error(e)
            rescue StandardError
              nil
              end
            update_success_import_count
          end

          def check_order_is_cancelled(order)
            shiping_easy_order = find_shipping_easy_order(order)
            handle_cancelled_order(shiping_easy_order)
          end

          def find_shipping_easy_order(order)
            shiping_easy_order = if !@credential.allow_duplicate_id && !@credential.store.split_order == 'shipment_handling_v2'
                                   Order.find_by_increment_id(@ext_identifier)
                                 else
                                   Order.find_by_store_order_id(order['id'])
                                 end
            shiping_easy_order
          end

          def create_alias_and_product(order_item, item)
            sku = item['sku'] || item['product']['sku']
            alias_skus = item['product']['sku_aliases']
            store_product_id = item['ext_line_item_id']
            product = create_product(sku, item['product'], store_product_id)
            create_alias(alias_skus, product) if alias_skus
            (item['product']['bundled_products'] || []).each do |kit_product|
              kit_pro = Product.joins(:product_skus).where('sku = ?', kit_product['sku'])
              new_kit_product = kit_pro.blank? ? create_product(kit_product['sku'], kit_product, store_product_id) : kit_pro[0]
              if ProductKitSkus.where(product_id: product.id, option_product_id: new_kit_product.id).blank?
                if new_kit_product.is_kit
                  on_demand_logger = Logger.new("#{Rails.root}/log/nested_kit_issue_#{Apartment::Tenant.current}.log")
                  log = { new_kit_product: new_kit_product, kit_product: kit_product, kit_pro: kit_pro, order_item: order_item, item: item, time: Time.current }
                  on_demand_logger.info(log)
                else
                  begin
                      product.product_kit_skuss.create(option_product_id: new_kit_product.id, qty: kit_product['quantity'])
                  rescue StandardError
                    nil
                    end
                end
              end
              kit_alias = kit_product['sku_aliases']
              create_alias(kit_alias, new_kit_product) if kit_alias
              product.update_attribute(:is_kit, 1)
            end
            create_order_item(item, order_item)
            s3_image_url = create_s3_image(item) if item['product']['image'].present? && item['product']['image']['original'].present? && product&.product_images&.blank?
            if s3_image_url&.present? && product.product_images.where(image: s3_image_url).blank?
              product.product_images.create(image: s3_image_url)
              # on_demand_logger = Logger.new("#{Rails.root}/log/duplicate_image_issue_#{Apartment::Tenant.current}.log")
              # log = {product_id: product.id, s3_image_url: s3_image_url, Time: Time.current}
              # on_demand_logger.info(log)
            end
            product.set_product_status
          end

          # def create_s3_image(item)
          #   image_data = Net::HTTP.get(URI.parse(item["product"]["image"]["original"]))
          #   # image_data = IO.read(open(item["product"]["image"]["original"]))
          #   file_name = "#{Time.current.strftime('%d_%b_%Y_%I__%M_%p')}_shipping_easy_#{item['sku'].downcase}"
          #   tenant = Apartment::Tenant.current
          #   GroovS3.create_image(tenant, file_name, image_data, 'public_read')
          #   s3_image_url = "#{ENV['S3_BASE_URL']}/#{tenant}/image/#{file_name}"
          #   return s3_image_url
          # end

          def create_order_item(item, order_item)
            order_item_product = begin
                                     Product.joins(:product_skus).where('product_skus.sku = ?', item['sku']).first
                                 rescue StandardError
                                   nil
                                   end
            order_item.product = order_item_product
            order_item.sku = item['sku']
            order_item.save
            make_product_intangible(order_item.product) if order_item.product.present?
          end

          def create_alias(alias_skus, product)
            alias_skus.each do |alias_sku|
              next if product.product_skus.map(&:sku).include? alias_sku

              begin
                  product.product_skus.create(sku: alias_sku)
              rescue StandardError
                nil
                end
            end
          end

          def create_product(sku, product_hash, store_product_id)
            product = Product.joins(:product_skus).where('product_skus.sku = ?', sku)[0]
            if product.blank?
              product_weight = product_hash['weight_in_ounces'] || '0.0'
              product_hash['description'] = "created by #{@credential.store.name}" if product_hash['description'].blank?
              if check_for_replace_product
                coupon_product = replace_product(product_hash['description'], sku)
                return coupon_product unless coupon_product.nil?
              end
              product = Product.create(name: product_hash['description'], store: @credential.store, store_product_id: store_product_id, weight: product_weight)
              product.product_skus.create(sku: sku)
              product.product_cats.create(category: product_hash['product_category_name'])
              product.product_lots.create(lot_number: product_hash['bin_picking_number'])
            end
            product.product_barcodes.create(barcode: product_hash['upc']) if product_hash['upc'].present? && (product.product_barcodes.map(&:barcode).exclude? product_hash['upc'])

            if @credential.gen_barcode_from_sku && ProductBarcode.where(barcode: sku).empty? && product.product_barcodes.blank?
              product.product_barcodes.create(barcode: sku)
            end
            product.isbn = product_hash['isbn'] if product_hash['isbn'].present?
            product.asin = product_hash['asin'] if product_hash['asin'].present?
            make_product_intangible(product)
            product.set_product_status
            product
          end

          def import_order(shiping_easy_order, order)
            total_weight = begin
                               order['recipients'][0]['original_order']['total_weight_in_ounces']
                           rescue StandardError
                             0
                             end
            custom_1 = begin
                           order['recipients'][0]['original_order']['custom_1']
                       rescue StandardError
                         nil
                         end
            custom_2 = begin
                           order['recipients'][0]['original_order']['custom_2']
                       rescue StandardError
                         nil
                         end
            custom_1 = @org_ext_identifier if custom_1.blank? && @credential.use_alternate_id_as_order_num
            origin_store_identifier = order.dig('recipients')&.first.dig('original_order','store_id')
            shiping_easy_order.assign_attributes(increment_id: @ext_identifier,
                                                 store_order_id: order['id'],
                                                 order_placed_time: order['ordered_at'].to_datetime,
                                                 email: order['billing_email'],
                                                 shipping_amount: order['base_shipping_cost'],
                                                 order_total: order['total_excluding_tax'],
                                                 notes_internal: order['internal_notes'],
                                                 weight_oz: total_weight,
                                                 custom_field_one: custom_1,
                                                 custom_field_two: custom_2,
                                                 customer_comments: order['notes'],
                                                 last_modified: order['updated_at'].to_datetime,
                                                 origin_store_id: origin_store_identifier,
                                                 prime_order_id: order['prime_order_id'],
                                                 source_order_ids: order['source_order_ids'].to_a.join(','),
                                                 split_from_order_id: order['split_from_order_id'],
                                                 importer_id: @worker_id,
                                                 import_item_id: @import_item.id)
            shiping_easy_order = update_shipping_address(shiping_easy_order, order)
          end

          def import_order_items_and_create_products(shiping_easy_order, order)
            unless order['recipients'].blank?
              merge_similar_sku = order['recipients'][0]['line_items'].map { |item| item['sku'] }.count - order['recipients'][0]['line_items'].map { |item| item['sku'] }.uniq.count
              import_item_count(order)
              order['recipients'][0]['line_items'].each do |item|
                order_item = shiping_easy_order.order_items.where(sku: item['sku']).first || shiping_easy_order.order_items.find_by(product_id: Product.joins(:product_skus).find_by(product_skus: { sku: item['sku'] })&.id)
                if (merge_similar_sku > 0 && shiping_easy_order.order_items.present? && order_item.present? && Store.find(shiping_easy_order.store_id).shipping_easy_credential.multiple_lines_per_sku_accepted) || order_item.present?
                  new_qty = order_item.qty + item['quantity']
                  new_price = order_item.price + item['unit_price'].to_f

                  order_item.assign_attributes(qty: new_qty,
                                               price: new_price,
                                               row_total: new_price.to_f * new_qty.to_f)
                else
                  order_item = shiping_easy_order.order_items.build
                  import_order_item(order_item, item)
                end
                if item['product'].present?
                  create_alias_and_product(order_item, item)
                else
                  import_single_order_product(order_item, item)
                end
                import_item_count
              end
            end

            return unless shiping_easy_order.save

            if Apartment::Tenant.current == 'verdantkitchen'
              on_demand_logger = Logger.new("#{Rails.root}/log/order_dupliacte _#{Apartment::Tenant.current}.log")
              log = { order_id: shiping_easy_order.increment_id, Time: Time.current }
              on_demand_logger.info(log)
            end

            shiping_easy_order.reload

            if check_for_replace_product
              add_order_activity_for_gp_coupon(shiping_easy_order, order['recipients'][0]['line_items'])
            else
              add_order_activity(shiping_easy_order)
            end
            shiping_easy_order.set_order_status
          end

          def import_order_item(ordr_item, item)
            ordr_item.assign_attributes(qty: item['quantity'],
                                        price: item['unit_price'],
                                        row_total: item['unit_price'].to_f * item['quantity'].to_f)
          end

          def import_single_order_product(order_item, item)
            # find_or_create_order_item_product is defined in products importer module
            order_item_product = find_or_create_order_item_product(item, @credential.store)
            order_item.product = order_item_product
            begin
              if item['product'].present? && ProductSku.find_by_sku(item['product']['sku']).try(:product).try(:product_images).blank?
                s3_image_url = create_s3_image(item) if item['product']['image'].present? && item['product']['image']['original'].present?
                order_item.product.product_images.create(image: s3_image_url) if s3_image_url.present?
              end
            rescue StandardError
            end
            make_product_intangible(order_item.product)
          end

          # def import_item_count(order=nil)
          #   unless order.blank?
          #     @import_item.current_order_items = order["recipients"][0]["line_items"].length
          #     @import_item.current_order_imported_item = 0
          #   else
          #     @import_item.current_order_imported_item = @import_item.current_order_imported_item + 1
          #   end
          #   @import_item.save
          # end

          # def init_common_objects
          #   handler = self.get_handler
          #   @credential = handler[:credential]
          #   @client = handler[:store_handle]
          #   @import_item = handler[:import_item]
          #   @import_item.update(updated_orders_import: 0)
          #   @result = self.build_result
          #   @statuses = get_statuses
          # end

          # def get_statuses
          #   status = ["cleared"]
          #   status << "ready_for_shipment" if @credential.import_ready_for_shipment
          #   status << "shipped" if @credential.import_shipped
          #   status << "pending_shipment" if @credential.ready_to_ship
          #   status
          # end

          def update_import_item_obj_values
            @import_item.update(current_increment_id: '', success_imported: 0, previous_imported: 0,
                                           current_order_items: -1, current_order_imported_item: -1, to_import: @result[:total_imported])
          end

          def update_shipping_address(shiping_easy_order, order)
            return shiping_easy_order if order['recipients'].blank?

            ship_addr = order['recipients'][0]
            shiping_easy_order.assign_attributes(lastname: ship_addr['last_name'], firstname: ship_addr['first_name'], address_1: ship_addr['address'],
                                                 address_2: ship_addr['address2'], city: ship_addr['city'], state: ship_addr['state'],
                                                 postcode: ship_addr['postal_code'], country: ship_addr['country'])
            shiping_easy_order
          end

          def update_current_import_item(order)
            @import_item.update(
              current_increment_id: order.try(:[], 'external_order_identifier'),
              current_order_items: -1,
              current_order_imported_item: -1
            )
          end

          def increase_import_count
            @result[:previous_imported] = @result[:previous_imported] + 1
            @import_item.previous_imported = @result[:previous_imported]
            @import_item.save
          end

          def import_statuses_are_empty
            return false unless @statuses.empty?

            @result[:status] = false
            @result[:messages].push('All import statuses disabled. Import skipped.')
            @import_item.update(message: 'All import statuses disabled. Import skipped.')
            true
          end

          def add_order_activity(shiping_easy_order)
            order_import_type = @on_demand_import ? 'On Demand Order Import' : 'Order Import'
            shiping_easy_order.addactivity(order_import_type, "#{@credential.store.name} Import #{@ondemand_user_name}")
            shiping_easy_order.order_items.each do |item|
              primary_sku = item.product.try(:primary_sku)
              next if primary_sku.nil?

              shiping_easy_order.addactivity("QTY #{item.qty} of item with SKU: #{primary_sku} Added", "#{@credential.store.name} Import")
            end
          end

          def add_order_activity_for_gp_coupon(shiping_easy_order, params_item)
            order_import_type = @on_demand_import ? 'On Demand Order Import' : 'Order Import'
            shiping_easy_order.addactivity(order_import_type, "#{@credential.store.name} Import #{@ondemand_user_name}")
            shiping_easy_order.order_items.each_with_index do |item, index|
              product_name = params_item[index]['product'].nil? ? params_item[index]['item_name'].to_s : params_item[index]['product']['description'].to_s
              if product_name == item.product.name && params_item[index]['sku'] == item.product.primary_sku
                primary_sku = item.product.try(:primary_sku)
                next if primary_sku.nil?

                shiping_easy_order.addactivity("QTY #{item.qty} of item with SKU: #{primary_sku} Added", "#{@credential.store.name} Import")
              elsif check_for_replace_product
                intangible_strings = ScanPackSetting.all.first.intangible_string.downcase.strip.split(',')
                activity_added = false
                intangible_strings.each do |string|
                  next unless product_name.downcase.include?(string) || params_item[index]['sku'].downcase.include?(string)

                  shiping_easy_order.addactivity("Intangible item with SKU #{params_item[index]['sku']}  and Name #{product_name} was replaced with GP Coupon.", "#{@credential.store.name} Import")
                  activity_added = true
                  break
                end
                shiping_easy_order.addactivity("QTY #{item.qty} of item with SKU: #{item.product.primary_sku} Added", "#{@credential.store.name} Import") if !activity_added && item.product.try(:primary_sku)
              end
            end
          end

          # def destroy_cleared_orders(response)
          #   skus = ProductKitSkus.where("option_product_id = product_id")
          #   skus.destroy_all
          #   orders_to_clear = Order.where("store_id=? and status!=? and increment_id in (?)", @credential.store_id, "scanned", response["cleared_orders_ids"])
          #   orders_to_clear.destroy_all
          # end

          def update_error_msg_if_any(response)
            return if response['error'].blank?

            @result[:status] &= false
            @result[:messages].push(response['error']['message'])
            @import_item.message = response['error']['message']
            @import_item.save
          end

          def skip_the_order?(order)
            # return false if @credential.import_shipped_having_tracking

            @credential.import_shipped_having_tracking && order['order_status'] == 'shipped' && order_tracking_number(order).nil?
          end

          def order_tracking_number(order)
            order['shipments'].select { |shipment| shipment['tracking_number'] != nil }.first.try(:[], 'tracking_number')
          end

          def get_ext_identifier(order)
            if @credential.use_alternate_id_as_order_num && order['alternate_order_id'].present?
              order['alternate_order_id']
            else
              order['external_order_identifier']
            end
          end
        end
      end
    end
  end
end
