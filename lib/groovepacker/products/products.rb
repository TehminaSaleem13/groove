module Groovepacker
  module Products
    class Products < Groovepacker::Products::Base

      def update_product_attributes        
        @product = Product.find_by_id(@params[:basicinfo][:id]) rescue nil
        @result['params'] = @params
        @result["exist_barcode"] = false
        multi_barcode = @params[:basicinfo][:multibarcode] rescue []
        apply_loop(multi_barcode)

        if @product.blank?
          @result.merge({'status' => false, 'message' => 'Cannot find product information.'})
          return @result
        end

        unless @current_user.can?('add_edit_products') || (@session[:product_edit_matched_for_current_user] && @session[:product_edit_matched_for_products].include?(@product.id))
          @result.merge({ 'status' => false, 'message' => 'You do not have enough permissions to update a product' })
          return @result
        end
        @product.reload
        @product = update_product_and_associated_info
        @product.update_product_status
        return @result
      end

      def apply_loop(multi_barcode)
        (multi_barcode.try(:values) || []).each do |barcode|
          multi = barcode
          barcode = ProductBarcode.find_by_id(multi[:id]) rescue nil
          if multi.present?
            if barcode.blank?
              if ProductBarcode.find_by_barcode(multi[:barcode]).present?
                @result["exist_barcode"] = true
              else
                ProductBarcode.create(barcode: multi[:barcode], product_id: @params[:basicinfo][:id], packing_count: multi[:packcount], is_multipack_barcode: true) 
              end
            elsif barcode.is_multipack_barcode #multi[:packcount].present?
              barcode.barcode = multi[:barcode]
              barcode.packing_count = multi[:packcount] 
              barcode.save
            end
          end
        end
      end

      def create_product_export(params, result, tenant)
        Apartment::Tenant.switch! tenant
        products = ProductsService::ListSelectedProducts.call(params, include_association = true)
        export_type = (params[:product][:is_kit] == 1 rescue nil) ? 'kits' : 'products'
        result['filename'] = export_type + '-'+Time.now.to_s+'.csv'
        CSV.open("#{Rails.root}/public/csv/#{result['filename']}", "w") do |csv|
          data = export_type == 'kits' ? ProductsHelper.kit_csv(products, csv) : ProductsHelper.products_csv(products, csv)
          result['filename'] = GroovS3.create_export_csv(Apartment::Tenant.current, result['filename'], data).url.gsub('http:', 'https:')
        end
        CsvExportMailer.send_s3_export_product_url(result['filename'], Apartment::Tenant.current).deliver
      end

      def ftp_product_import(tenant)
        stores = Store.joins(:ftp_credential).where('product_ftp_host IS NOT NULL and product_ftp_username IS NOT NULL and product_ftp_password IS NOT NULL and status=true and store_type = ? && ftp_credentials.use_product_ftp_import = ?', 'CSV', true)
        stores.each do |store|
          params = {}
          mapping = CsvMapping.find_by_store_id(store.id)
          next unless check_connection_for_product_ftp_import(mapping, store)
          map = mapping.product_csv_map
          map.map[:map] = map.map[:map].class == ActionController::Parameters ? map.map[:map].permit!.to_h : map.map[:map] rescue nil
          data = build_product_data(map,store)
          data[:tenant] = tenant
          data[:user_id] = User.find_by_name('gpadmin').try(:id)
          ImportCsv.new.delay(:run_at => 1.seconds.from_now, :queue => "import_products_from_csv#{Apartment::Tenant.current}", priority: 95).import Apartment::Tenant.current, data.to_s
        end
      end

      def check_connection_for_product_ftp_import(mapping, store)
        status = true
        unless !mapping.nil? && !mapping.product_csv_map.nil? && store.ftp_credential.product_ftp_username && store.ftp_credential.product_ftp_password && store.ftp_credential.product_ftp_host
          status = false
        end
        return status
      end

      def build_product_data(map,store)
        data = {:flag => "ftp_download", :type => "product", :store_id => store.id}
        common_product_ftp_data_attributes.each { |attr| data[attr.to_sym] = map[:map][attr.to_sym] }
        return data
      end

      def common_product_ftp_data_attributes
        return ["fix_width", "fixed_width", "sep", "delimiter", "rows", "map", "map", "import_action",
                "contains_unique_order_items", "generate_barcode_from_sku", "use_sku_as_product_name",
                "order_date_time_format", "day_month_sequence"
              ]
      end

      private
        def general_setting
          @general_settings ||= GeneralSetting.all.first
        end

        def update_product_and_associated_info
          update_product_basic_info #Update Basic Info
          update_product_location #Update Location
          update_inventory_info rescue nil#Update Inventory Info
          updatelist(@product, 'status', @params[:basicinfo][:status]) unless @params[:basicinfo][:status].nil? #Update product status and also update the containing kit and orders
          update_category_sku_barcode #Update product category, sku and barcode
          create_or_update_product_images #Update or update product images
          update_product_kit_skus #if product is a kit, update product_kit_skus
          @product.reload
        end

        def update_category_sku_barcode
          return if @params['post_fn'].blank?
          # if @params['post_fn'] == ''
          #   #Update product inventory warehouses
          #   #check if a product inventory warehouse is defined.
          #   product_inv_whs = ProductInventoryWarehouses.where(:product_id => @product.id)

          #   if product_inv_whs.length > 0
          #     product_inv_whs.each do |inv_wh|
          #       if UserInventoryPermission.where(
          #         :user_id => @current_user.id,
          #         :inventory_warehouse_id => inv_wh.inventory_warehouse_id,
          #         :edit => true
          #       ).length > 0
          #         found_inv_wh = false
          #         unless @params[:inventory_warehouses].nil?
          #           @params[:inventory_warehouses].each do |wh|
          #             if wh["info"]["id"] == inv_wh.id
          #               found_inv_wh = true
          #             end
          #           end
          #         end
          #         if found_inv_wh == false
          #           if !inv_wh.destroy
          #             @result['status'] &= false
          #           end
          #         end
          #       end
          #     end
          #   end

          #   #Update product inventory warehouses
          #   #check if a product category is defined.
          #   if !@params[:inventory_warehouses].nil?
          #     general_setting = GeneralSetting.all.first
          #     @params[:inventory_warehouses].each do |wh|
          #       if UserInventoryPermission.where(
          #         :user_id => @current_user.id,
          #         :inventory_warehouse_id => wh['warehouse_info']['id'],
          #         :edit => true
          #       ).length > 0
          #         if !wh["info"]["id"].nil?
          #           product_inv_wh = ProductInventoryWarehouses.find(wh["info"]["id"])

          #           if general_setting.low_inventory_alert_email
          #             product_inv_wh.product_inv_alert = wh["info"]["product_inv_alert"]
          #             product_inv_wh.product_inv_alert_level = wh["info"]["product_inv_alert_level"]
          #           end
          #           product_inv_wh.quantity_on_hand= wh["info"]["quantity_on_hand"]
          #           # product_inv_wh.available_inv = wh["info"]["available_inv"]
          #           product_inv_wh.location_primary = wh["info"]["location_primary"]
          #           product_inv_wh.location_secondary = wh["info"]["location_secondary"]
          #           product_inv_wh.location_tertiary = wh["info"]["location_tertiary"]
          #           unless product_inv_wh.save
          #             @result['status'] &= false
          #           end
          #         elsif !wh["warehouse_info"]["id"].nil?
          #           product_inv_wh = ProductInventoryWarehouses.new
          #           product_inv_wh.product_id = @product.id
          #           product_inv_wh.inventory_warehouse_id = wh["warehouse_info"]["id"]
          #           unless product_inv_wh.save
          #             @result['status'] &= false
          #           end
          #         end
          #       end
          #     end
          #   end
          # end

          case @params['post_fn']
          when 'category'
          	create_or_update_product_cats
          when 'sku'
          	create_or_update_product_skus
          when 'barcode'
          	create_or_update_product_barcode
          end
        end

        def create_or_update_product_cats
          #Update product categories
          #check if a product category is defined.
          product_cats = ProductCat.where(:product_id => @product.id)
          @result = destroy_object_if_not_defined(product_cats, @params[:cats], 'category')
          (@params[:cats]||[]).each do |category|
            status = @product.create_or_update_productcat(category, product_cats)
            @result['status'] &= status
          end
        end

        def create_or_update_product_skus(status = true)
          #Update product skus
          #check if a product sku is defined.
          product_skus = ProductSku.where(:product_id => @product.id)
          @result = destroy_object_if_not_defined(product_skus, @params[:skus], 'sku')
          (@params[:skus]||[]).each_with_index do |sku, index|
            status = create_or_update_single_sku(sku, index, true, product_skus)
            @result['status'] &= status
          end
        end

        def create_or_update_single_sku(sku, index, status, product_skus)
          db_sku =
            product_skus.find{|_sku| _sku.sku == sku["sku"]} ||
            ProductSku.find_by_sku(sku["sku"])
          
          if sku["id"].present?
            db_sku = product_skus.find{|_sku| _sku.id == sku["id"]}
            # status = @product.create_or_update_productsku(sku, index, nil, db_sku, @current_user)
            status = @product.create_or_update_product_sku_or_barcode(sku, index, nil, db_sku, @current_user, 'SKU')
          elsif sku["sku"].present? && db_sku.blank?
            # status = @product.create_or_update_productsku(sku, index, 'new', @current_user)
            status = @product.create_or_update_product_sku_or_barcode(sku, index, 'new', @current_user, 'SKU')
          elsif sku["sku"].present? && db_sku.present?
            @result['status'] = false
            @result['message'] = "Sku "+sku["sku"]+" already exists"
          end
          return status
        end

        def create_or_update_product_barcode
          #Update product barcodes
          #check if a product barcode is defined.
          product_barcodes = ProductBarcode.where(:product_id => @product.id)
          @result = destroy_object_if_not_defined(product_barcodes, @params[:barcodes], 'barcode')
          return if @params[:barcodes].blank?
          @params[:barcodes].each_with_index do |barcode, index|
            @result['status'] &= create_or_update_single_barcode(barcode, index, true, product_barcodes)
          end
        end

        def create_or_update_single_barcode(barcode, index, status, product_barcodes)
          db_barcode = 
            product_barcodes.find{|_bar| _bar.barcode == barcode["barcode"]} ||
            ProductBarcode.find_by_barcode(barcode["barcode"])

          case true
          when barcode["id"].present?
            db_barcode = product_barcodes.find{|_bar| _bar.id == barcode["id"]}
            if barcode["barcode"].present? && (@product.product_barcodes.where('id != ?', db_barcode.id).pluck(:barcode).include? barcode["barcode"])
              @result['status'] = false
              @result['message'] = "The Barcode \"#{barcode['barcode']}\" is already associated with this product"
              status = false
            else
              status = @product.create_or_update_product_sku_or_barcode(barcode, index, nil, db_barcode, @current_user, 'barcode')
            end
          when barcode["barcode"].present? && db_barcode.blank?
            # status = @product.create_or_update_productbarcode(barcode, index, 'new', @current_user)
            status = @product.create_or_update_product_sku_or_barcode(barcode, index, 'new', @current_user, 'barcode')
          when barcode["barcode"].present? && db_barcode.present? && (@product.product_barcodes.pluck(:barcode).exclude? barcode["barcode"])
            if barcode[:permit_same_barcode]
              status = @product.create_or_update_product_sku_or_barcode(barcode, index, 'new', @current_user, 'barcode')
            else
              @result['current_product_data'] = { id: @product.id, name: @product.name, sku: @product.product_skus.map(&:sku).join(', '), barcode: @product.product_barcodes.map(&:barcode).join(', ') }
              @result['alias_product_data'] = { id: db_barcode.product.id, name: db_barcode.product.name, sku: db_barcode.product.product_skus.map(&:sku).join(', '), barcode: db_barcode.product.product_barcodes.map(&:barcode).join(', ') }
              @result['after_alias_product_data'] = @result['alias_product_data'].dup
              @result['after_alias_product_data'][:sku] = (@result['alias_product_data'][:sku].split(', ') << @product.product_skus.map(&:sku)).flatten.compact.join(', ')
              @result['shared_bacode_products'] = ProductBarcode.get_shared_barcode_products(barcode['barcode'])
              @result['matching_barcode'] = barcode['barcode']
              @result['show_alias_popup'] = true
              status = true
            end
            # @result['status'] = false
            # @result['message'] = "The Barcode \"#{barcode['barcode']}\" is already associated with: <br> #{db_barcode.product.name} <br> #{db_barcode.product.primary_sku}"
          when barcode["barcode"].present? && db_barcode.present?
            @result['status'] = false
            @result['message'] = "Barcode #{barcode['barcode']} already exists"
            status = false
          end
          return status
        end

        def create_or_update_product_images
          product_images = ProductImage.where(:product_id => @product.id)
          @result = destroy_object_if_not_defined(product_images, @params[:images], 'image')
          (@params[:images]||[]).each_with_index do |image, index|
            unless @product.create_or_update_productimage(image, index, product_images)
              @result['status'] &= false
            end
          end
        end

        def update_product_kit_skus
          kit_products = ProductKitSkus.where(product_id: @product.id)
          (@params[:productkitskus]||[]).each do |kit_product|
            @product.create_or_update_productkitsku(kit_product, kit_products)
          end
        end

        def update_inventory_info
          return if @params[:inventory_warehouses].blank?
          attr_array = get_inv_update_attributes

          @params[:inventory_warehouses].each_with_index do |inv_wh|
            update_single_warehouse_info(inv_wh, attr_array)
          end
        end

        def update_single_warehouse_info(inv_wh, attr_array)
          product_location = @product.product_inventory_warehousess.find_by_id(inv_wh["info"]["id"])
          attr_array.each do |attr|
            product_location.send("#{attr}=", inv_wh[:info][attr])
          end
          @product.touch if product_location.changes.include? 'location_primary'
          product_location.save
        end

        def get_inv_update_attributes
          attr_array = ['quantity_on_hand', 'location_primary', 'location_secondary', 'location_tertiary', 'location_quaternary', 'location_primary_qty', 'location_secondary_qty', 'location_tertiary_qty', 'location_quaternary_qty']
          attr_array = attr_array + ['product_inv_alert', 'product_inv_alert_level'] if general_setting.low_inventory_alert_email
          attr_array
        end

        def destroy_object_if_not_defined(objects_array, obj_params, type)
          return @result if objects_array.blank?
          ids = obj_params.map {|obj| obj["id"]}.compact rescue []
          objects_array.each do |object|
            found_obj = false
            found_obj = true if ids.include?(object.id)
            if found_obj == false && type == "sku"
              object.product.add_product_activity("The #{type} #{object.sku} was deleted from this item", @current_user.name)
            elsif found_obj == false && type == "barcode"
              object.product.add_product_activity("The #{type} #{object.barcode}  was deleted from this item", @current_user.name)
            end   

            @result['status'] &= false if found_obj == false && !object.destroy
          end
          return @result
        end

        def update_product_basic_info
          basic_info = @params[:basicinfo]
          @product.add_product_activity("The Product Name of this item was changed from #{@product.name} to #{basic_info["name"]} ",@current_user.username)  if @product.name != basic_info["name"]
          unless @product.is_kit == basic_info["is_kit"]
            type = basic_info["is_kit"] == 0 ? "product" : "kit"
            @product.add_product_activity("This item was changed to a #{type}", @current_user.name)  
          end
          attrs_to_update.each {|attr| @product[attr] = basic_info[attr] }
          @product.packing_placement = basic_info[:packing_placement] if basic_info[:packing_placement].is_a?(Integer)
          @product.weight = @product.get_product_weight(@params[:weight])
          @product.shipping_weight = @product.get_product_weight(@params[:shipping_weight])
          @product.weight_format = get_weight_format(basic_info[:weight_format])
          @product.status = basic_info[:status] if basic_info[:status].present?
          @product.fnsku = basic_info[:fnsku]
          @product.asin = basic_info[:asin]
          @product.fba_upc = basic_info[:fba_upc]
          @product.isbn = basic_info[:isbn]
          @product.ean = basic_info[:ean]
          @product.supplier_sku = basic_info[:supplier_sku]
          @product.avg_cost = basic_info[:avg_cost].to_f
          @product.count_group = basic_info[:count_group].chars.first if basic_info[:count_group]
          @result['status'] &= false unless @product.save
        end

        def attrs_to_update
          [ "disable_conf_req", "is_kit", "is_skippable", "record_serial", "kit_parsing", "name", "product_type",
            "packing_instructions_conf", "packing_instructions", "store_id", "store_product_id",
            "type_scan_enabled", "click_scan_enabled", "add_to_any_order", "product_receiving_instructions",
            "is_intangible", "pack_time_adj" , "second_record_serial","custom_product_1", "custom_product_2", "custom_product_3", "custom_product_display_1", "custom_product_display_2", "custom_product_display_3"]
        end

        def update_product_location
          product_location = @product.primary_warehouse
          if product_location.nil?
            product_location = ProductInventoryWarehouses.new
            product_location.product_id = @product.id
            product_location.inventory_warehouse_id = @current_user.inventory_warehouse_id
          end

          unless @params[:inventory_warehouses].blank?
            qua_on_hand = @params[:inventory_warehouses][0][:info][:quantity_on_hand]
            @product.add_product_activity("The QOH of this item was changed from #{product_location.quantity_on_hand} to #{qua_on_hand} ", @current_user.name)  if product_location.quantity_on_hand != qua_on_hand
            product_location.quantity_on_hand = @params[:inventory_warehouses][0][:info][:quantity_on_hand]
          end
          product_location.save
        end

    end
  end
end
