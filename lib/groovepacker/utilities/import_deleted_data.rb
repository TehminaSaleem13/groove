class ImportDeletedData
	def import_users(ordo)
		ordo[1].each do |ou|
			next unless User.where(id: ou['id'].to_i).empty?
      user = User.new
      user.id = ou['id'].to_i
      user.encrypted_password = ou['encrypted_password']
      user.reset_password_token = ou['reset_password_token']
      user.reset_password_sent_at = ou['reset_password_sent_at'].to_datetime
      user.remember_created_at = ou['remember_created_at'].to_datetime
      user.sign_in_count = ou['sign_in_count'].to_i
      user.current_sign_in_at = ou['current_sign_in_at'].to_datetime
      user.last_sign_in_at = ou['last_sign_in_at'].to_datetime
      user.current_sign_in_ip = ou['current_sign_in_ip']
      user.last_sign_in_ip = ou['last_sign_in_ip']
      user.created_at = ou['created_at'].to_datetime
      user.updated_at = ou['updated_at'].to_datetime
      user.username = ou['username']
      user.active = ou['active'].to_b
      user.other = ou['other']
      user.name = ou['name']
      user.confirmation_code = ou['confirmation_code']
      user.inventory_warehouse_id = ou['inventory_warehouse_id'].to_i
      user.role_id = ou['role_id'].to_i
      user.edit_user_status = ou['edit_user_status'].to_b
      user.add_order_items_ALL = ou['add_order_items_ALL'].to_b
      user.order_edit_confirmation_code = ou['order_edit_confirmation_code']
      user.product_edit_confirmation_code = ou['product_edit_confirmation_code']
      user.view_dashboard = ou['view_dashboard'].to_b
      user.save
    end
	end

	def import_stores(ordo)
		ordo[1].each do |os|
			next unless Store.where(id: os['id'].to_i).empty?
      store = Store.new
      store.id = store['id'].to_i
      store.name = os['name']
      store.status = os['status'].to_b
      store.store_type = os['store_type']
      store.order_date = os['order_date'].to_datetime
      store.created_at = os['created_at'].to_datetime
      store.updated_at = os['updated_at'].to_datetime
      store.inventory_warehouse_id = os['inventory_warehouse_id'].to_i
      store.thank_you_message_to_customer = os['thank_you_message_to_customer']
      store.auto_update_products = os['auto_update_products'].to_b
      store.update_inv = os['update_inv'].to_b
      store.save
    end
	end

	def import_orders(ordo)
		return unless Order.where(id: ordo[1]['id'].to_i).empty?
		order = Order.new
    order.id = ordo[1]['id'].to_i
    order.increment_id = ordo[1]['increment_id']
    order.order_placed_time = ordo[1]['order_placed_time'].to_datetime
    order.sku = ordo[1]['sku']
    order.customer_comments = ordo[1]['customer_comments']
    order.store_id = ordo[1]['store_id'].to_i
    order.qty = ordo[1]['qty'].to_i
    order.price = ordo[1]['price']
    order.firstname = ordo[1]['firstname']
    order.lastname = ordo[1]['lastname']
    order.email = ordo[1]['email']
    order.address_1 = ordo[1]['address_1']
    order.address_2 = ordo[1]['address_2']
    order.city = ordo[1]['city']
    order.state = ordo[1]['state']
    order.postcode = ordo[1]['postcode']
    order.country = ordo[1]['country']
    order.method = ordo[1]['method']
    order.created_at = ordo[1]['created_at'].to_datetime
    order.updated_at = ordo[1]['updated_at'].to_datetime
    order.notes_internal = ordo[1]['notes_internal']
    order.notes_toPacker = ordo[1]['notes_toPacker']
    order.notes_fromPacker = ordo[1]['notes_fromPacker']
    order.tracking_processed = ordo[1]['tracking_processed'].to_b
    order.status = ordo[1]['status']
    order.scanned_on = ordo[1]['scanned_on'].to_datetime
    order.tracking_num = ordo[1]['tracking_num']
    order.company = ordo[1]['company']
    order.packing_user_id = ordo[1]['packing_user_id'].to_i
    order.status_reason = ordo[1]['status_reason']
    order.order_number = ordo[1]['order_number']
    order.seller_id = ordo[1]['seller_id'].to_i
    order.order_status_id = ordo[1]['order_status_id'].to_i
    order.ship_name = ordo[1]['ship_name']
    order.shipping_amount = ordo[1]['shipping_amount'].to_f
    order.order_total = ordo[1]['order_total'].to_f
    order.notes_from_buyer = ordo[1]['notes_from_buyer']
    order.weight_oz = ordo[1]['weight_oz'].to_i
    order.non_hyphen_increment_id = ordo[1]['non_hyphen_increment_id']
    order.note_confirmation = ordo[1]['note_confirmation'].to_b
    order.store_order_id = ordo[1]['store_order_id']
    order.inaccurate_scan_count = ordo[1]['inaccurate_scan_count'].to_i
    order.scan_start_time = ordo[1]['scan_start_time'].to_datetime
    order.reallocate_inventory = ordo[1]['reallocate_inventory'].to_b
    order.last_suggested_at = ordo[1]['last_suggested_at'].to_datetime
    order.total_scan_time = ordo[1]['total_scan_time'].to_i
    order.total_scan_count = ordo[1]['total_scan_count'].to_i
    order.packing_score = ordo[1]['packing_score'].to_f
    order.custom_field_one = ordo[1]['custom_field_one']
    order.custom_field_two = ordo[1]['custom_field_two']
    order.traced_in_dashboard = ordo[1]['traced_in_dashboard'].to_b
    order.save
	end

  def import_products(ordo)
    ordo[1].each do |item|
      next unless Product.where(id: item['id'].to_i).empty?
      product = Product.new
      product.id = item['id'].to_i
      product.store_product_id = item['store_product_id']
      product.name = item['name']
      product.product_type = item['product_type']
      product.store_id = item['store_id'].to_i
      product.created_at = item['created_at'].to_datetime
      product.updated_at = item['updated_at'].to_datetime
      product.status = item['status']
      product.spl_instructions_4_packer = item['spl_instructions_4_packer']
      product.spl_instructions_4_confirmation = item['spl_instructions_4_confirmation'].to_b
      product.is_skippable = item['is_skippable'].to_b
      product.packing_placement = item['packing_placement'].to_i
      product.pack_time_adj = item['pack_time_adj'].to_i
      product.kit_parsing = item['kit_parsing']
      product.disable_conf_req = item['disable_conf_req'].to_b
      product.total_avail_ext = item['total_avail_ext'].to_i
      product.weight = item['weight'].to_f
      product.shipping_weight = item['shipping_weight'].to_f
      product.record_serial = item['record_serial'].to_b
      product.type_scan_enabled = item['type_scan_enabled']
      product.click_scan_enabled = item['click_scan_enabled']
      product.weight_format = item['weight_format']
      product.add_to_any_order = item['add_to_any_order'].to_b
      product.base_sku = item['base_sku']
      product.is_intangible = item['is_intangible'].to_b
      product.is_kit = item['is_kit'].to_i
      product.product_receiving_instructions = item['product_receiving_instructions']
      product.save
    end
  end

	def import_order_activities(ordo)
		ordo[1].each do |oa|
			next unless OrderActivity.where(id: oa['id'].to_i).empty?
      order_activity = OrderActivity.new
      order_activity.id = oa['id'].to_i
      order_activity.activitytime = oa['activitytime'].to_datetime
      order_activity.order_id = oa['order_id'].to_i
      order_activity.user_id = oa['user_id'].to_i
      order_activity.action = oa['action']
      order_activity.created_at = oa['created_at'].to_datetime
      order_activity.updated_at = oa['updated_at'].to_datetime
      order_activity.username = oa['username']
      order_activity.activity_type = oa['activity_type']
      order_activity.acknowledged = oa['acknowledged'].to_b
      order_activity.save
    end
	end

	def import_order_exception(ordo)
		return unless OrderException.where(id: ordo[1]['id'].to_i).empty?
		order_exception = OrderException.new
    order_exception.id = ordo[1]['id'].to_i
    order_exception.reason = ordo[1]['reason']
    order_exception.description = ordo[1]['description']
    order_exception.user_id = ordo[1]['user_id'].to_i
    order_exception.created_at = ordo[1]['created_at'].to_datetime
    order_exception.updated_at = ordo[1]['updated_at'].to_datetime
    order_exception.order_id = ordo[1]['order_id'].to_i
    order_exception.save
	end

	def import_order_shipping(ordo)
		return unless OrderShipping.where(id: ordo[1]['id'].to_i).empty?
		order_shipping = OrderShipping.new
    order_shipping.id = ordo[1]['id'].to_i
    order_shipping.firstname = ordo[1]['firstname']
    order_shipping.lastname = ordo[1]['lastname']
    order_shipping.email = ordo[1]['email']
    order_shipping.streetaddress1 = ordo[1]['streetaddress1']
    order_shipping.streetaddress2 = ordo[1]['streetaddress2']
    order_shipping.city = ordo[1]['city']
    order_shipping.region = ordo[1]['region']
    order_shipping.postcode = ordo[1]['postcode']
    order_shipping.country = ordo[1]['country']
    order_shipping.description = ordo[1]['description']
    order_shipping.order_id = ordo[1]['order_id'].to_i
    order_shipping.created_at = ordo[1]['created_at'].to_datetime
    order_shipping.updated_at = ordo[1]['updated_at'].to_datetime
    order_shipping.save
	end

	def import_order_serials(ordo)
		ordo[1].each do |os|
			next unless OrderSerail.where(id: os['id'].to_i).empty?
      order_serial = OrderSerail.new
      order_serial.id = os['id'].to_i
      order_serial.order_id = os['order_id'].to_i
      order_serial.product_id = os['product_id'].to_i
      order_serial.serail = os['serail']
      order_serial.created_at = os['created_at'].to_datetime
      order_serial.updated_at = os['updated_at'].to_datetime
      order_serial.save
    end
	end

	def import_order_items(ordo)
		ordo[1].each do |oi|
			next unless OrderItem.where(id: oi['id'].to_i).empty?
      order_item = OrderItem.new
      order_item.id = oi['id'].to_i
      order_item.sku = oi['sku']
      order_item.qty = oi['qty'].to_i
      order_item.price = oi['price'].to_f
      order_item.row_total = oi['row_total'].to_f
      order_item.order_id = oi['order_id'].to_i
      order_item.created_at = oi['created_at'].to_datetime
      order_item.updated_at = oi['updated_at'].to_datetime
      order_item.name = oi['name']
      order_item.product_id = oi['product_id'].to_i
      order_item.scanned_status = oi['scanned_status']
      order_item.scanned_qty = oi['scanned_qty'].to_i
      order_item.kit_split = oi['kit_split'].to_b
      order_item.kit_split_qty = oi['kit_split_qty'].to_i
      order_item.kit_split_scanned_qty = oi['kit_split_scanned_qty'].to_i
      order_item.single_scanned_qty = oi['single_scanned_qty'].to_i
      order_item.inv_status = oi['inv_status']
      order_item.inv_status_reason = oi['inv_status_reason']
      order_item.clicked_qty = oi['clicked_qty'].to_i
      order_item.is_barcode_printed = oi['is_barcode_printed'].to_b
      order_item.save
    end
	end

	def import_order_item_kit_products(ordo)
		ordo[1].each do |oitp|
			next unless OrderItemKitProduct.where(id: oitp['id'].to_i).empty?
      item_kit_prod = OrderItemKitProduct.new
      item_kit_prod.id = oitp['id'].to_i
      item_kit_prod.order_item_id = oitp['order_item_id'].to_i
      item_kit_prod.product_kit_skus_id = oitp['product_kit_skus_id'].to_i
      item_kit_prod.scanned_status = oitp['scanned_status']
      item_kit_prod.scanned_qty = oitp['scanned_qty'].to_i
      item_kit_prod.created_at = oitp['created_at'].to_datetime
      item_kit_prod.updated_at = oitp['updated_at'].to_datetime
      item_kit_prod.clicked_qty = oitp['clicked_qty'].to_i
      item_kit_prod.save
    end
	end

	def import_order_item_order_serial_product_lots(ordo)
		ordo[1].each do |item|
			next unless OrderItemOrderSerialProductLot.where(id: item['id'].to_i).empty?
	    oiosp = OrderItemOrderSerialProductLot.new
      oiosp.id = item['id'].to_i
	    oiosp.order_item_id = item['order_item_id'].to_i
	    oiosp.product_lot_id = item['product_lot_id'].to_i
	    oiosp.order_serial_id = item['order_serial_id'].to_i
	    oiosp.created_at = item['created_at'].to_datetime
	    oiosp.updated_at = item['updated_at'].to_datetime
	    oiosp.qty = item['qty'].to_i
	    oiosp.save
	  end
	end

	def import_order_item_scan_times(ordo)
		ordo[1].each do |item|
			next unless OrderItemScanTime.where(id: item['id'].to_i).empty?
      oist = OrderItemScanTime.new
      oist.id = item['id'].to_i
      oist.scan_start = item['scan_start'].to_datetime
      oist.scan_end = item['scan_end'].to_datetime
      oist.order_item_id = item['order_item_id'].to_i
      oist.created_at = item['created_at'].to_datetime
      oist.updated_at = item['updated_at'].to_datetime
      oist.save
    end
	end
end
