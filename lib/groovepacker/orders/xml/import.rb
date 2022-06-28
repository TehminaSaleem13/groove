module Groovepacker
  module Orders
    module Xml
      class Import
        attr_accessor :order
        include ProductsHelper
        def initialize(file_name, csv_name, flag)
          @order = Groovepacker::Orders::Xml::OrderXml.new(file_name)
          @file_name = csv_name
          @ftp_flag = flag
        end

        def process
          tenant = Apartment::Tenant.current
          @current_tenant = tenant
          result = {status: true, errors: [], order: nil}
          order = Order.includes(order_items: :product).find_by_increment_id(@order.increment_id)
          @old_order = Order.find_by_increment_id(@order.increment_id)
          @update_count = 0
          @emit_value = false
          # if order exists, update the order and order items
          # order does not exist create order
          if order.nil?
            order = Order.new
            @check_new_order = true
            order.increment_id = @order.increment_id
            n = $redis.get("new_order_#{tenant}").to_i + 1
            $redis.set("new_order_#{tenant}" , n)
          end
          @store = Store.find(@order.store_id) || order.store

          unless (order.try(:status) == "scanned" ||  order.try(:order_items).map(&:scanned_status).include?("partially_scanned") ||  order.try(:order_items).map(&:scanned_status).include?("scanned"))
            if check_for_update || @check_new_order
              ["store_id", "firstname", "lastname", "email", "address_1", "address_2",
              "city", "state", "country", "postcode", "order_placed_time", "tracking_num",
              "custom_field_one", "custom_field_two", "method", "order_total",
              "customer_comments", "tags", "notes_toPacker", "notes_fromPacker", "notes_internal", "price"].each do |attr|
              order[attr] = @order.send(attr)
                end
            end
          end

          if @old_order.try(:attributes) != order.attributes
            @update_count = @update_count + 1
          end
          # update all order related info
          order_persisted = order.persisted? ? true : false
          begin
            if order.save!
              if @current_tenant.in? %w[living unitedmedco toririchard]
                order_item_dup = OrderItem.where("created_at >= ?", Time.current.beginning_of_day).select(:order_id).group(:order_id, :product_id).having("count(*) > 1").count
                unless order_item_dup.empty?
                  order_item_dup.each do |i|
                    item = OrderItem.where(order_id: i[0][0], product_id: i[0][1])
                    item.last.destroy if item.count > 1
                  end
                end
              end
              order.addactivity("Order Import", "#{@store.try(:name)} Import") unless order_persisted
              # @order[:order_items] = @order.order_items
              order_item_result = process_order_items(order, @order)
              if order_item_result[:status]
                order.reload
                # update order status
                order.update_order_status
              else
                # order.destroy
              end
              result[:status] = order_item_result[:status]
              result[:errors] = order_item_result[:errors]
            else
              result[:status] = false
              result[:errors] = order.errors.full_messages
              result[:order] = nil
            end
            if result[:status]
              upload_res = @order.save
              if upload_res.nil?
                result[:status] = false
                result[:errors] = ["Error uploading to S3."]
              else
                order.import_s3_key = upload_res
                order.save!
              end
            end
            if $redis.get("is_create_barcode_#{tenant}") == "true"
              order.generate_order_barcode_for_html(order.increment_id)
            end
          rescue Exception => e
            logger = Logger.new("#{Rails.root}/log/error_log_order_save_on_csv_import_#{Apartment::Tenant.current}.log")
            logger.info("Order save Error ============#{e}")
            if (Apartment::Tenant.current == "living" || Apartment::Tenant.current == "unitedmedco" || Apartment::Tenant.current == "toririchard")
              a = Order.group(:increment_id).having("count(*) >1").count.keys
              unless a.empty?
                Order.where("increment_id in (?)", a).each do |o|
                  orders = Order.where(increment_id: o.increment_id)
                  orders.last.destroy if orders.count > 1
                end
              end
            end
          end

          setting = ScanPackSetting.all.first
          order.order_items.map(&:product).reject(&:blank?).each do |product|
            #product.set_product_status
            intangible_strings = setting.intangible_string.split(",")
            intangible_setting_enabled = setting.intangible_setting_enabled
            if intangible_setting_enabled
              intangible_strings.each do |string|
                action_intangible = Groovepacker::Products::ActionIntangible.new
                if ((product.name).downcase.include? (string.downcase)) || action_intangible.send(:sku_starts_with_intangible_string, product, string)
                  product.is_intangible = true
                  product.save
                end
              end
            end
          end
          # update the importsummary if import summary is available
          if !@order.import_summary_id.nil? && OrderImportSummary.find_by_id(@order.import_summary_id)
            begin
              order_import_summary = OrderImportSummary.find(@order.import_summary_id)
              import_item = order_import_summary.import_items.where(store_id: @store.id)
              if import_item.empty?
                import_item = order_import_summary.import_items
              end
              import_item = import_item.first
              import_item.update(updated_orders_import: 0) if import_item.updated_orders_import.nil?
              @time_of_import = import_item.created_at
              if import_item
                import_item.with_lock do
                  import_item.to_import = @order.total_count
                  if result[:status]
                    import_item.status = "in_progress"
                    if order_persisted
                      import_item.updated_orders_import += 1
                    else
                      import_item.success_imported += 1
                    end
                  else
                    #import_summary.failed_imported += 1
                  end
                  # if all are finished then mark as completed
                  import_item.updated_orders_import = 0 unless import_item.updated_orders_import
                  if import_item.updated_orders_import + import_item.success_imported == @order.total_count
                    if check_count_is_equle?
                      import_item.status = "completed"
                      orders = $redis.smembers("#{Apartment::Tenant.current}_csv_array")
                      begin

                        n = Order.where('created_at > ?',$redis.get("last_order_#{tenant}")).count rescue 0
                        @after_import_count = $redis.get("total_orders_#{tenant}").to_i + n

                        if orders.count == @after_import_count - $redis.get("total_orders_#{tenant}").to_i && $redis.get("new_order_#{tenant}").to_i != 0
                          $redis.set("new_order_#{tenant}" , orders.count)
                        end

                        new_orders_count = @after_import_count -  $redis.get("total_orders_#{tenant}").to_i
                        $redis.set("new_order_#{tenant}", new_orders_count)

                        $redis.set("skip_order_#{Apartment::Tenant.current}", import_item.updated_orders_import) if import_item.updated_orders_import != ($redis.get("update_order_#{tenant}").to_i + $redis.get("skip_order_#{Apartment::Tenant.current}").to_i)

                        if @ftp_flag == "false"
                          @file_name = $redis.get("#{Apartment::Tenant.current}/original_file_name")
                          $redis.del("#{Apartment::Tenant.current}/original_file_name")
                        end
                        log = AddLogCsv.new
                        log.add_log_csv(Apartment::Tenant.current,@time_of_import,@file_name)
                      rescue
                      end

                      if @ftp_flag == "true"
                        orders = $redis.smembers("#{Apartment::Tenant.current}_csv_array")
                        order_ids = Order.where("increment_id in (?) and created_at >= ? and created_at <= ?", orders, Time.current.beginning_of_day, Time.current.end_of_day).pluck(:id)
                        item_hash = OrderItem.where("order_id in (?)", order_ids).group([:order_id, :product_id]).having("count(*) > 1").count
                        ImportMailer.order_information(@file_name,item_hash).deliver if item_hash.present?
                        groove_ftp = FTP::FtpConnectionManager.get_instance(@store)
                        begin

                          if @after_import_count - $redis.get("new_order_#{tenant}").to_i ==  $redis.get("total_orders_#{tenant}").to_i || $redis.get("new_order_#{tenant}").to_i + $redis.get("update_order_#{tenant}").to_i + $redis.get("skip_order_#{tenant}").to_i == orders.count
                            response = groove_ftp.update(@file_name)
                          else
                            ImportMailer.not_imported(@file_name, orders.count,$redis.get("new_order_#{tenant}").to_i ,$redis.get("update_order_#{tenant}").to_i, $redis.get("skip_order_#{tenant}").to_i, $redis.get("total_orders_#{tenant}").to_i, @after_import_count ).deliver
                          end
                        rescue
                        end
                        ftp_csv_import = Groovepacker::Orders::Import.new
                        ftp_csv_import.ftp_order_import(Apartment::Tenant.current)
                      end
                      #$redis.expire("#{Apartment::Tenant.current}_csv_file_increment_id_index", 1)
                    else
                      import_item.status = "cancelled"
                      #ImportMailer.order_skipped(@file_name, @skipped_count, @order.store_id, @skipped_ids).deliver
                      if @ftp_flag == "true"
                        ftp_csv_import = Groovepacker::Orders::Import.new
                        ftp_csv_import.ftp_order_import(Apartment::Tenant.current)
                      end
                    end
                  end
                  @emit_value  = (import_item.changes["status"].to_a & ["not_started", "completed"]).any?
                  import_item.save
                  if @emit_value
                    import_summary = OrderImportSummary.top_summary
                    unless import_summary.nil?
                      import_summary.emit_data_to_user(true)
                    end
                  end
                end
              end
            rescue Exception => e
              Rollbar.error(e, e.message, Apartment::Tenant.current)
            end
          end

          result
        end

        private
        def check_count_is_equle?
          orders = $redis.smembers("#{Apartment::Tenant.current}_csv_array")
          db_orders = Order.where(increment_id: orders).map(&:increment_id)
          return true if db_orders.count == @order.total_count && orders.count == @order.total_count
          @skipped_count = @order.total_count - db_orders.count
          @skipped_ids = orders - db_orders
          return true if @order.total_count == 1 && @store.fba_import == true
          false
        end

        def process_order_items(order, orderXML)
          result = { status: true, errors: [] }

          unless (order.try(:status) == "scanned" ||  order.try(:order_items).map(&:scanned_status).include?("partially_scanned") || order.try(:order_items).map(&:scanned_status).include?("scanned"))
            if order.order_items.empty?
              # create order items
              orderXML.order_items.each do |order_item_XML|
                create_update_order_item(order, order_item_XML)
              end
            else
              # if order item exists in the current order but does not exist in XML order
              # then delete the order item
              if check_for_update
                delete_existing_order_items(order, orderXML)

                orderXML.order_items.each do |order_item_XML|
                  create_update_order_item(order, order_item_XML)
                end
              end
            end
          end
          if !@check_new_order
            if @update_count >= 1
              n =  $redis.get("update_order_#{Apartment::Tenant.current}").to_i + 1
              $redis.set("update_order_#{Apartment::Tenant.current}", n)
            else
              n = $redis.get("skip_order_#{Apartment::Tenant.current}").to_i + 1
              $redis.set("skip_order_#{Apartment::Tenant.current}", n)
            end
          end
          result
        end

        def delete_existing_order_items(order, orderXML)
          # If an order contains aliased item & original one then destroy all existing items.
          check_if_contains_aliased_products(orderXML.order_items)

          order.order_items.includes([product: [:product_skus]]).each do |order_item|
            if @destroy_all_existing
              order_item.destroy
            else
              found = false
              first_sku = order_item.product.product_skus.first
              unless first_sku.nil?
                first_sku = first_sku.sku
                orderXML.order_items.each do |order_item_XML|
                  unless order_item_XML[:product][:skus].index(first_sku).nil?
                    found = true
                  end
                end
              end
              unless found
                order_item.destroy
              end
            end
          end
        end

        def create_update_order_item(order, order_item_XML)
          @gp_coupon_found  = false
          first_sku = order_item_XML[:product][:skus].first
          unless first_sku.nil?
            product_sku = ProductSku.includes(product: :store).find_by_sku(first_sku)
            if product_sku.nil?
              # add product
              if check_for_replace_product
                coupon_product = replace_product(order_item_XML[:product][:name], first_sku)
                if coupon_product.nil?
                  product = Product.new
                  product.store = @store
                else
                  product = coupon_product
                  @gp_coupon_found  = true
                end
              else
                product = Product.new
                product.store = @store
              end
            else
              product = product_sku.product
            end
            result = create_update_product(product, order_item_XML[:product])
            product.set_product_status
            if result[:status]
              if order.order_items.where(product_id: product.id).empty?
                order.order_items.create(sku: first_sku, qty: (order_item_XML[:qty] || 0),
                product_id: product.id, price: order_item_XML[:price])
                if check_for_replace_product && @gp_coupon_found == true
                  order.addactivity("Intangible item with SKU #{order_item_XML[:product][:skus].first}  and Name #{order_item_XML[:product][:name]} was replaced with GP Coupon.","#{@store.name} Import")
                else
                  order.addactivity("QTY #{order_item_XML[:qty] || 0 } of item with SKU: #{product.primary_sku} Added",
                  "#{@store.name} Import")
                end
              else
                order_item = order.order_items.where(product_id: product.id)
                unless order_item.empty?
                  order_item = order_item.first
                  order_item.sku = first_sku
                  tenant = Apartment::Tenant.current
                  if !(order_item_XML[:qty].to_i == order_item.qty && order_item.price ==  order_item_XML[:price])
                    if check_for_update
                      @update_count = @update_count + 1
                    end
                  end

                  if check_for_update
                    # Add qty if existing aliased item is found
                    order_item_XML[:qty] = order_item_XML[:qty].to_i + order_item.qty if @destroy_all_existing
                    order_item.qty = order_item_XML[:qty] || 0
                    order_item.price = order_item_XML[:price]
                    order_item.save
                  end
                end
              end
            end
          end
        end

        def check_if_contains_aliased_products(order_items)
          existing_products = []
          order_items.map { |i| i[:product][:skus].first }.each do |sku|
            existing_products << Product.joins(:product_skus).find_by(product_skus: { sku: sku })&.id
          end
          # Check if an order contains same item more than once.
          @destroy_all_existing = existing_products.compact.uniq.size != existing_products.compact.size
        end

        def check_for_update
          tenant = Apartment::Tenant.current
          $redis.get("import_action_#{tenant}") == "" || $redis.get("import_action_#{tenant}") == "update_order"
        end

        def create_update_product(product, product_xml)
          result = {  status: true, errors: [], product: nil }
          #product information
          return result if @gp_coupon_found == true
          product.name = product_xml[:name] if product.name.blank?
          product.packing_instructions = product_xml[:instructions] if product.packing_instructions.blank?
          product.is_kit = product_xml[:is_kit] if product.is_kit == 0
          product.kit_parsing = product_xml[:kit_parsing] if product.kit_parsing.blank?
          product.weight = product_xml[:weight] if product.weight.blank?
          product.weight_format = product_xml[:weight_format] if product.weight_format.blank?

          if product.save
            #images
            product.add_product_activity("Product Import","#{product.store.try(:name)}") unless product.product_activities.any?
            product_xml[:images].each do |product_image|
              if product.product_images.where(image: product_image).empty?
                product.product_images.create(image: product_image)
              end
            end

            #categories
            product_xml[:categories].each do |product_category|
              if product.product_cats.where(category: product_category).empty?
                product.product_cats.create(category: product_category)
              end
            end

            #skus
            product_xml[:skus].each do |product_sku|
              if product.product_skus.where(sku: product_sku).empty?
                product.product_skus.create(sku: product_sku)
              end
            end

            #barcodes
            product_xml[:barcodes].each do |product_barcode|
              if product.product_barcodes.where(barcode: product_barcode).empty?
                product.product_barcodes.create(barcode: product_barcode)
              end
            end
            #product.update_product_status
            result[:product] = product
          else
            result[:status] = false
            result[:errors] = product.errors.full_messages
          end
          result
        end
      end
    end
  end
end
