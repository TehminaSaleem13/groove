module ProductService
  class ProductInfo
    include ProductsHelper

    def initialize(attrs={})
      @result = attrs[:result]
      @params = attrs[:params]
      @current_user = attrs[:current_user]
    end

    def get_product_info
      @params[:id] = nil if @params[:id]=="null"
			if @params[:id].present?
				@product = Product.find_by_id(@params[:id])
			else
				prod_barcodes = ProductBarcode.where(:barcode => @params[:barcode])
				if prod_barcodes.length > 0
					@product = prod_barcodes.first.product
				end
			end
			if @product.present?
				@product.reload
				store_id = @product.store_id
				stores = Store.where(:id => store_id)
				if !stores.nil?
					@store = stores.first
				end
				general_setting = GeneralSetting.all.first
				scan_pack_setting = ScanPackSetting.all.first
				amazon_products = AmazonCredentials.where(:store_id => store_id)
				unless amazon_products.blank?
					@amazon_product = amazon_products.first
				end

				@result['product'] = Hash.new
				@result['product']['amazon_product'] = @amazon_product
				@result['product']['store'] = @store
				@result['product']['sync_option'] = @product.sync_option.attributes rescue nil
				@result['product']['access_restrictions'] = AccessRestriction.last rescue nil
				@result['product']['basicinfo'] = @product.attributes
				@result['product']['basicinfo']['weight_format'] = @product.get_show_weight_format
				@result['product']['basicinfo']['contains_intangible_string'] = @product.contains_intangible_string
				@result['product']['product_weight_format'] = GeneralSetting.get_product_weight_format
				@result['product']['weight'] = @product.get_weight
				@result['product']['shipping_weight'] = @product.get_shipping_weight
				@result['product']['skus'] = @product.product_skus.order("product_skus.order ASC")
				@result['product']['cats'] = @product.product_cats
				@result['product']['spl_instructions_4_packer'] = @product.spl_instructions_4_packer
				@result['product']['images'] = @product.base_product.product_images.order("product_images.order ASC")
				@result['product']['barcodes'] = @product.product_barcodes.order("product_barcodes.order ASC")
				@result['product']['inventory_warehouses'] = []

				@product.product_inventory_warehousess.each do |inv_wh|
					if UserInventoryPermission.where(
						:user_id => @current_user.id,
						:inventory_warehouse_id => inv_wh.inventory_warehouse_id,
						:see => true
					).length > 0
						inv_wh_result = Hash.new
						inv_wh_result['info'] = inv_wh.attributes
						inv_wh_result['info']['quantity_on_hand'] = inv_wh.quantity_on_hand
						unless general_setting.low_inventory_alert_email
							inv_wh_result['info']['product_inv_alert'] = false
						end
						unless inv_wh_result['info']['product_inv_alert']
							inv_wh_result['info']['product_inv_alert_level'] = general_setting.default_low_inventory_alert_limit
						end
						inv_wh_result['warehouse_info'] = nil
						unless inv_wh.inventory_warehouse_id.nil?
							inv_wh_result['warehouse_info'] = InventoryWarehouse.find(inv_wh.inventory_warehouse_id)
						end
						@result['product']['inventory_warehouses'] << inv_wh_result
					end
				end
				#@result['product']['productkitskus'] = @product.product_kit_skuss
				@result['product']['productkitskus'] = []
				if @product.is_kit
					@product.product_kit_skuss.each do |kit|
						option_product = Product.find(kit.option_product_id)

						kit_sku = Hash.new
						kit_sku['name'] = option_product.name
						kit_sku['product_status'] = option_product.status
						if option_product.product_skus.length > 0
							kit_sku['sku'] = option_product.primary_sku
						end
						kit_sku['qty'] = kit.qty
						kit_sku['available_inv'] = 0
						kit_sku['qty_on_hand'] = 0
						option_product.product_inventory_warehousess.each do |inventory|
							kit_sku['available_inv'] += inventory.available_inv.to_i
							kit_sku['qty_on_hand'] += inventory.quantity_on_hand.to_i
						end
						kit_sku['packing_order'] = kit.packing_order
						kit_sku['option_product_id'] = option_product.id
						@result['product']['productkitskus'].push(kit_sku)
					end
					@result['product']['productkitskus'] =
						@result['product']['productkitskus'].sort_by { |hsh| hsh['packing_order'] }
					@result['product']['product_kit_activities'] = @product.product_kit_activities
					@result['product']['unacknowledged_kit_activities'] = @product.unacknowledged_kit_activities
				end

				if @product.product_skus.length > 0
					@result['product']['pendingorders'] = Order.where(:status => 'awaiting').where(:status => 'onhold').
						where(:sku => @product.product_skus.first.sku)
				else
					@result['product']['pendingorders'] = nil
				end
			end

      return @result
    end

  end
end
