module Groovepacker
  module Products
    class Products < Groovepacker::Products::Base

      def update_product_attributes
        @product = Product.find_by_id(@params[:basicinfo][:id]) rescue nil
        @result['params'] = @params
        
        if @product.blank?
          @result.merge({'status' => false, 'message' => 'Cannot find product information.'})
          return @result
        end
        
        unless @current_user.can?('add_edit_products') || (session[:product_edit_matched_for_current_user] && session[:product_edit_matched_for_products].include?(@product.id))
          @result.merge({ 'status' => false, 'message' => 'You do not have enough permissions to update a product' })
          return @result
        end
        @product.reload
        @product = update_product_and_associated_info
        @product.update_product_status
        return @result
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
          @result = destroy_object_if_not_defined(product_cats, @params[:cats])
          (@params[:cats]||[]).each do |category|
            status = @product.create_or_update_productcat(category)
            @result['status'] &= status
          end
        end

        def create_or_update_product_skus(status = true)
          #Update product skus
          #check if a product sku is defined.
          product_skus = ProductSku.where(:product_id => @product.id)
          @result = destroy_object_if_not_defined(product_skus, @params[:skus])
          (@params[:skus]||[]).each_with_index do |sku, index|
            status = create_or_update_single_sku(sku, index, true)
            @result['status'] &= status
          end
        end

        def create_or_update_single_sku(sku, index, status)
          if sku["id"].present?
            status = @product.create_or_update_productsku(sku, index)
          elsif sku["sku"].present? && ProductSku.where(:sku => sku["sku"]).blank?
            status = @product.create_or_update_productsku(sku, index, 'new')
          elsif sku["sku"].present?
            @result['status'] = false
            @result['message'] = "Sku "+sku["sku"]+" already exists"
          end
          return status
        end
        
        def create_or_update_product_barcode
          #Update product barcodes
          #check if a product barcode is defined.
          product_barcodes = ProductBarcode.where(:product_id => @product.id)
          @result = destroy_object_if_not_defined(product_barcodes, @params[:barcodes])
          return if @params[:barcodes].blank?
          @params[:barcodes].each_with_index { |barcode, index| @result['status'] &= create_or_update_single_barcode(barcode, index, true) }
        end

        def create_or_update_single_barcode(barcode, index, status)
          case true
          when barcode["id"].present?
            status = @product.create_or_update_productbarcode(barcode, index)
          when barcode["barcode"].present? && ProductBarcode.where(:barcode => barcode["barcode"]).blank?
            status = @product.create_or_update_productbarcode(barcode, index, 'new')
          when barcode["barcode"].present?
            @result['status'] = false
            @result['message'] = "Barcode #{barcode['barcode']} already exists"
            status = false
          end
          return status
        end

        def create_or_update_product_images
          product_images = ProductImage.where(:product_id => @product.id)
          @result = destroy_object_if_not_defined(product_images, @params[:images])
          (@params[:images]||[]).each_with_index do |image, index|
            unless @product.create_or_update_productimage(image, index)
              @result['status'] &= false
            end
          end
        end

        def update_product_kit_skus
          (@params[:productkitskus]||[]).each do |kit_product|
            @product.create_or_update_productkitsku(kit_product)
          end
        end

        def update_inventory_info
          return if @params[:inventory_warehouses].empty?
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
          product_location.save
        end

        def get_inv_update_attributes
          attr_array = ['quantity_on_hand', 'location_primary', 'location_secondary', 'location_tertiary']
          if general_setting.low_inventory_alert_email
            attr_array = attr_array + ['product_inv_alert', 'product_inv_alert_level']
          end
          attr_array
        end

        def destroy_object_if_not_defined(objects_array, obj_params)
          return @result if objects_array.blank?

          ids = obj_params.map {|obj| obj["id"]} rescue []
          objects_array.each do |object|
            found_obj = false
            found_obj = true if ids.include?(object.id)
            if found_obj == false && !object.destroy
              @result['status'] &= false
            end
          end
          return @result
        end

        def update_product_basic_info
          basic_info = @params[:basicinfo]
          attrs_to_update.each {|attr| @product[attr] = basic_info[attr] }

          @product.packing_placement = basic_info[:packing_placement] if basic_info[:packing_placement].is_a?(Integer)
          @product.weight = @product.get_product_weight(@params[:weight])
          @product.shipping_weight = @product.get_product_weight(@params[:shipping_weight])
          @product.weight_format = get_weight_format(basic_info[:weight_format])
          @result['status'] &= false unless @product.save
        end

        def attrs_to_update
          [ "disable_conf_req", "is_kit", "is_skippable", "record_serial", "kit_parsing", "name", "product_type",
            "spl_instructions_4_confirmation", "spl_instructions_4_packer", "store_id", "store_product_id",
            "type_scan_enabled", "click_scan_enabled", "add_to_any_order", "product_receiving_instructions",
            "is_intangible", "pack_time_adj" ]
        end

        def update_product_location
          product_location = @product.primary_warehouse
          if product_location.nil?
            product_location = ProductInventoryWarehouses.new
            product_location.product_id = @product.id
            product_location.inventory_warehouse_id = @current_user.inventory_warehouse_id
          end

          product_location.quantity_on_hand = @params[:inventory_warehouses][0][:info][:quantity_on_hand] unless @params[:inventory_warehouses].empty?
          product_location.save
        end

    end
  end
end
