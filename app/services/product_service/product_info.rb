module ProductService
  class ProductInfo
    include ProductsHelper

    def initialize(attrs={})
      @result = attrs[:result]
      @params = attrs[:params]
      @current_user = attrs[:current_user]
    end

    def get_product_info
      find_product
      return @result unless @product.present?
      @product.reload
      @store = Store.find_by_id(@product.store_id)
      @amazon_product = AmazonCredentials.find_by_store_id(@product.store_id)
      @result['product'] = {}
      get_product_basic_and_access_info
      get_product_inventory_info
      get_productkitskus_and_activities
      get_pending_orders_of_products
      return @result
    end

  	private
      def find_product
        @params[:id] = nil if @params[:id]=="null"
        if @params[:id].present?
        	@product = Product.find_by_id(@params[:id])
        else
          prod_barcode = ProductBarcode.find_by_barcode(@params[:barcode])
          @product = prod_barcode.product if prod_barcode
        end
      end

      def general_setting
      	@settings ||= GeneralSetting.all.first
      end

      def scan_pack_setting
      	@scanpack_settings ||= ScanPackSetting.all.first
      end

      def get_product_basic_and_access_info
        @result['product'] = @result['product'].merge({ 'amazon_product' => @amazon_product,
                                                        'store' => @store,
                                                        'basicinfo' => @product.attributes,
                                                        'product_weight_format' => get_product_weight_format,
                                                        'weight' => @product.get_weight,
                                                        'shipping_weight' => @product.get_shipping_weight,
                                                        'skus' => get_product_skus,
                                                        'cats' => @product.product_cats,
                                                        'spl_instructions_4_packer' => @product.spl_instructions_4_packer,
                                                        'images' => get_base_product_images,
                                                        'barcodes' => get_product_barcodes,
                                                        'sync_option' => sync_option_attrs,
                                                        'access_restrictions' => get_access_restriction_info
                                                     })
        @result['product']['basicinfo']['weight_format'] = @product.get_show_weight_format
        @result['product']['basicinfo']['contains_intangible_string'] = @product.contains_intangible_string
      end

      def sync_option_attrs
        @product.sync_option.attributes rescue nil
      end

      def get_access_restriction_info
      	AccessRestriction.last rescue nil
      end

      def get_product_weight_format
      	GeneralSetting.get_product_weight_format
      end

      def get_product_skus
      	@product.product_skus.order("product_skus.order ASC")
      end

      def get_base_product_images
      	@product.base_product.product_images.order("product_images.order ASC")
      end

      def get_product_barcodes
      	@product.product_barcodes.order("product_barcodes.order ASC")
      end

      def get_product_inventory_info
      	@result['product']['inventory_warehouses'] = []
      	@product.product_inventory_warehousess.each do |inv_wh|
      	  inv_wh_result = get_single_inv_warehouse_info(inv_wh)
      	  next if inv_wh_result.blank?
      	  @result['product']['inventory_warehouses'] << inv_wh_result
        end
  	  end

  	  def get_single_inv_warehouse_info(inv_wh)
      	inv_permission = UserInventoryPermission.where( :user_id => @current_user.id,
                                                        :inventory_warehouse_id => inv_wh.inventory_warehouse_id,
                                                        :see => true
                                                      )
      	return nil if inv_permission.blank?
        inv_wh_result = {}
        inv_wh_result['info'] = inv_wh.attributes
        inv_wh_result['info']['quantity_on_hand'] = inv_wh.quantity_on_hand
        
        unless general_setting.low_inventory_alert_email
          inv_wh_result['info']['product_inv_alert'] = false
          inv_wh_result['info']['product_inv_alert_level'] = general_setting.default_low_inventory_alert_limit
        end

        inv_wh_result['warehouse_info'] = InventoryWarehouse.find_by_id(inv_wh.inventory_warehouse_id)
        return inv_wh_result
      end

      def get_productkitskus_and_activities
        #@result['product']['productkitskus'] = @product.product_kit_skuss
        @result['product']['productkitskus'] = []
        return unless @product.is_kit
        @product.product_kit_skuss.each do |kit|
          @result['product']['productkitskus'] << get_single_productkitsku_attrs(kit)
        end
        @result['product']['productkitskus'] = @result['product']['productkitskus'].sort_by { |hsh| hsh['packing_order'] }
        @result['product']['product_kit_activities'] = @product.product_kit_activities
        @result['product']['unacknowledged_kit_activities'] = @product.unacknowledged_kit_activities
      end

      def get_single_productkitsku_attrs(kit)
        option_product = Product.find_by_id(kit.option_product_id)
        kit_sku = { 'name' => option_product.name,
                    'product_status' => option_product.status,
                    'qty' => kit.qty,
                    'available_inv' => 0,
                    'qty_on_hand' => 0,
                    'packing_order' => kit.packing_order,
                    'option_product_id' => option_product.id
                  }

        kit_sku['sku'] = option_product.primary_sku rescue nil
          
        option_product.product_inventory_warehousess.each do |inventory|
          kit_sku['available_inv'] += inventory.available_inv.to_i
          kit_sku['qty_on_hand'] += inventory.quantity_on_hand.to_i
        end
        return kit_sku
      end

      def get_pending_orders_of_products
        @result['product']['pendingorders'] = nil
        return unless @product.product_skus.length > 0
        pending_orders = Order.where(:status => 'awaiting', :status => 'onhold', :sku => @product.product_skus.first.sku)
        @result['product']['pendingorders'] = pending_orders
      end

  end
end
