module Groovepacker
  module Orders
    module Xml
      class Import
        attr_accessor :order

        def initialize(file_name, csv_name, flag)
          @order = Groovepacker::Orders::Xml::OrderXml.new(file_name)
          @file_name = csv_name
          @ftp_flag = flag
        end

        def process
          tenant = Apartment::Tenant.current
          result = {status: true, errors: [], order: nil}
          order = Order.find_by_increment_id(@order.increment_id)
          @old_order = Order.find_by_increment_id(@order.increment_id)
          @update_count = 0
          # if order exists, update the order and order items
          # order does not exist create order
          if order.nil?
            order = Order.new
            @check_new_order = true 
            order.increment_id = @order.increment_id
            n = $redis.get("new_order_#{tenant}").to_i + 1
            $redis.set("new_order_#{tenant}" , n)
          end


          unless (order.try(:status) == "scanned" ||  order.try(:order_items).map(&:scanned_status).include?("partially_scanned") ||  order.try(:order_items).map(&:scanned_status).include?("scanned"))
            if check_for_update 
              ["store_id", "firstname", "lastname", "email", "address_1", "address_2",
              "city", "state", "country", "postcode", "order_placed_time", "tracking_num", 
              "custom_field_one", "custom_field_two", "method", "order_total",
              "customer_comments", "notes_toPacker", "notes_fromPacker", "notes_internal", "price"].each do |attr|
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
              item_hash = order.order_items.group([:order_id, :product_id]).having("count(*) > 1").count
              if item_hash.any?
                on_demand_logger = logger = Logger.new("#{Rails.root}/log/duplicate_order_item_#{Apartment::Tenant.current}.log")
                on_demand_logger.info("=========================================")
                log = { tenant: Apartment::Tenant.current, order_items_hash: item_hash , order: @order.order_items}  
                on_demand_logger.info(log)
                on_demand_logger.info("=========================================")
              end
              order.addactivity("Order Import", "#{order.store.try(:name)} Import") unless order_persisted
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
          rescue Exception => e
            logger = Logger.new("#{Rails.root}/log/error_log_order_save_on_csv_import_#{Apartment::Tenant.current}.log")
            logger.info("Order save Error ============#{e}")
          end

          setting = ScanPackSetting.all.first
          order.order_items.map(&:product).each do |product|  
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
          if !@order.import_summary_id.nil?
            begin
              order_import_summary = OrderImportSummary.find(@order.import_summary_id)
              import_item = order_import_summary.import_items.where(store_id: order.store_id)
              if import_item.empty?
                import_item = order_import_summary.import_items
              end
              import_item = import_item.first
              @time_of_import = import_item.created_at 
              if import_item
                import_item.with_lock do
                  import_item.to_import = @order.total_count
                  if result[:status]
                    import_item.status = "in_progress"
                    if order_persisted
                      import_item.previous_imported += 1
                    else
                      import_item.success_imported += 1
                    end
                  else
                    #import_summary.failed_imported += 1
                  end
                  # if all are finished then mark as completed
                  if import_item.previous_imported + import_item.success_imported == @order.total_count
                    if check_count_is_equle?
                      import_item.status = "completed"
                      orders = $redis.smembers("#{Apartment::Tenant.current}_csv_array")
                      begin
                        
                        n = Order.where('created_at > ?',$redis.get("last_order_#{tenant}")).count rescue 0
                        @after_import_count = $redis.get("total_orders_#{tenant}").to_i + n

                        if orders.count == @after_import_count - $redis.get("total_orders_#{tenant}").to_i && $redis.get("new_order_#{tenant}").to_i != 0
                          $redis.set("new_order_#{tenant}" , orders.count)
                        end
                        
                        unless $redis.get("new_order_#{tenant}").to_i + $redis.get("update_order_#{tenant}").to_i + $redis.get("skip_order_#{tenant}").to_i == orders.count
                          ImportMailer.not_imported(@file_name, orders.count,$redis.get("new_order_#{tenant}").to_i ,$redis.get("update_order_#{tenant}").to_i, $redis.get("skip_order_#{tenant}").to_i, $redis.get("total_orders_#{tenant}").to_i, @after_import_count ).deliver
                        end

                        time_zone = GeneralSetting.last.time_zone.to_i
                        time_of_import_tz =  @time_of_import + time_zone
                        
                        on_demand_logger = Logger.new("#{Rails.root}/log/import_order_info_#{Apartment::Tenant.current}.log")
                        log = {"Time_Stamp_Tenant_TZ" => "#{time_of_import_tz}","Time_Stamp_UTC" => "#{@time_of_import}" , "Tenant" => "#{Apartment::Tenant.current}","Name_of_imported_file" => "#{@file_name}","Orders_in_file" => "#{orders.count}".to_i, "New_orders_imported" => "#{$redis.get("new_order_#{tenant}")}".to_i, "Existing_orders_updated" =>"#{$redis.get("update_order_#{tenant}")}".to_i , "Existing_orders_skipped" => "#{$redis.get("skip_order_#{tenant}")}".to_i, "Orders_in_GroovePacker_before_import" => "#{$redis.get("total_orders_#{tenant}")}".to_i, "Orders_in_GroovePacker_after_import" =>"#{@after_import_count}".to_i }
                        on_demand_logger.info(log)
                        
                        pdf_path = Rails.root.join( 'log', "import_order_info_#{Apartment::Tenant.current}.log")
                        reader_file_path = Rails.root.join('log', "import_order_info_#{Apartment::Tenant.current}.log")
                        base_file_name = File.basename(pdf_path)
                        pdf_file = File.open(reader_file_path)
                        GroovS3.create_log(Apartment::Tenant.current, base_file_name, pdf_path.read)
                      rescue Exception => e
                        logger = Logger.new("#{Rails.root}/log/check_for_hung_#{Apartment::Tenant.current}.log")
                        logger.info(e)
                      end
                    
                      if @ftp_flag == "true"
                        orders = $redis.smembers("#{Apartment::Tenant.current}_csv_array")
                        order_ids = Order.where("increment_id in (?) and created_at >= ? and created_at <= ?", orders, Time.now.beginning_of_day, Time.now.end_of_day).pluck(:id)
                        item_hash = OrderItem.where("order_id in (?)", order_ids).group([:order_id, :product_id]).having("count(*) > 1").count
                        ImportMailer.order_information(@file_name,item_hash).deliver if item_hash.present?
                        groove_ftp = FTP::FtpConnectionManager.get_instance(order.store)
                        begin

                          if @after_import_count - $redis.get("new_order_#{tenant}").to_i ==  $redis.get("total_orders_#{tenant}").to_i || $redis.get("new_order_#{tenant}").to_i + $redis.get("update_order_#{tenant}").to_i + $redis.get("skip_order_#{tenant}").to_i == orders.count
                            response = groove_ftp.update(@file_name)
                          else
                            ImportMailer.not_imported(@file_name, orders.count,$redis.get("new_order_#{tenant}").to_i ,$redis.get("update_order_#{tenant}").to_i, $redis.get("skip_order_#{tenant}").to_i, $redis.get("total_orders_#{tenant}").to_i, @after_import_count ).deliver
                          end
                        rescue Exception => e
                          logger = Logger.new("#{Rails.root}/log/after_import.log")
                          logger.info(e)
                        end
                        ftp_csv_import = Groovepacker::Orders::Import.new
                        ftp_csv_import.ftp_order_import(Apartment::Tenant.current)
                      end
                      $redis.expire("#{Apartment::Tenant.current}_csv_file_increment_id_index", 1)
                    else
                      import_item.status = "cancelled"
                      ImportMailer.order_skipped(@file_name, @skipped_count, @order.store_id, @skipped_ids).deliver
                      if @ftp_flag == "true"
                        ftp_csv_import = Groovepacker::Orders::Import.new
                        ftp_csv_import.ftp_order_import(Apartment::Tenant.current)
                      end
                    end
                  end
                  import_item.save
                end
              end
            rescue Exception => e
              logger = Logger.new("#{Rails.root}/log/error_log_csv_import_#{Apartment::Tenant.current}.log")
              logger.info("=========================================")
              logger.info(e)
              logger.info(e.backtrace.join(",")) rescue logger.info(e)
            end
          end

          result
        end

        private
        def check_count_is_equle?
          logger = Logger.new("#{Rails.root}/log/check_count_#{Apartment::Tenant.current}.log")
          orders = $redis.smembers("#{Apartment::Tenant.current}_csv_array")
          logger.info("orders array from redis ============================== #{orders}")
          db_orders = Order.where(increment_id: orders).map(&:increment_id)
          return true if db_orders.count == @order.total_count && orders.count == @order.total_count
          @skipped_count = @order.total_count - db_orders.count
          @skipped_ids = orders - db_orders
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
          order.order_items.each do |order_item|
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

        def create_update_order_item(order, order_item_XML)
          first_sku = order_item_XML[:product][:skus].first
          unless first_sku.nil?
            product_sku = ProductSku.find_by_sku(first_sku)
            if product_sku.nil?
              # add product
              product = Product.new
              product.store = order.store
            else
              product = product_sku.product
            end
            result = create_update_product(product, order_item_XML[:product])
            product.set_product_status
            if result[:status]
              if order.order_items.where(product_id: product.id).empty?
                order.order_items.create(sku: first_sku, qty: (order_item_XML[:qty] || 0),
                product_id: product.id, price: order_item_XML[:price])
                order.addactivity("QTY #{order_item_XML[:qty] || 0 } of item with SKU: #{product.primary_sku} Added", 
                  "#{order.store.name} Import")
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
                    order_item.qty = order_item_XML[:qty] || 0
                    order_item.price = order_item_XML[:price]
                    order_item.save
                  end
                end
              end
            end
          end
        end

        def check_for_update
          tenant = Apartment::Tenant.current
          $redis.get("import_action_#{tenant}") == "" || $redis.get("import_action_#{tenant}") == "update_order"
        end

        def create_update_product(product, product_xml)
          result = {  status: true, errors: [], product: nil }
          #product information
          product.name = product_xml[:name] if product.name.blank?
          product.spl_instructions_4_packer = product_xml[:instructions] if product.spl_instructions_4_packer.blank?
          product.is_kit = product_xml[:is_kit] if product.is_kit == 0
          product.kit_parsing = product_xml[:kit_parsing] if product.kit_parsing.blank?
          product.weight = product_xml[:weight] if product.weight.blank?
          product.weight_format = product_xml[:weight_format] if product.weight_format.blank?
          if product.save
            #images
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