module OrderClassMethodsHelper
  def create_new_order(result, current_user)
    order = Order.new(store_id: Store.where(store_type: 'system').first.id, status: "onhold", order_placed_time: Time.current.utc)
    order.save
    result['order'] = order
    result
  end

  def emit_data_for_on_demand_import(hash, order_no)
    if hash["orders"].blank?
      result = {"status" => false, "message" => "Order #{order_no} could not be found and downloaded. Please check your order source to verify this order exists."}
      GroovRealtime::emit('popup_display_for_on_demand_import', result, :tenant)
    end
  end

  def emit_notification_ondemand_quickfix(user_id)
    result = {"status" => true, "message" => 'It appears that the order scanned is more recent than any of the orders that have been imported. An import will be run to fetch all new orders. Please continue scanning once the import completes.', "user_id" => "#{user_id}" }
    GroovRealtime::emit('notification_ondemand_quickfix', result, :tenant)
  end

  def emit_data_for_on_demand_import_v2(hash, order_no, user_id)
    if hash["orders"].blank?
      result = {"status" => false, "user_id" => "#{user_id}", "message" => "Please verify that order #{order_no} is available in your order manager. They were not able to provide it on our request"}
      GroovRealtime::emit('popup_display_for_on_demand_import_v2', result, :tenant)
    else
      result = {"status" => true, "message" => "Order #{order_no} is Ready and will open in:", "id" => "#{order_no}", "user_id" => "#{user_id}" }
      GroovRealtime::emit('popup_display_for_on_demand_import_v2', result, :tenant)
    end
  end

  def emit_notification_all_status_disabled(user_id)
    result = {"status" => true, "message" => "All import option switches are disabled. Please refer to <a target='_blank' href='https://groovepacker.freshdesk.com/en/support/solutions/articles/6000058013-shipstation-order-status-tag-import-options'><u style='color: antiquewhite;'>this article</u></a> for help.", "user_id" => "#{user_id}" }
    GroovRealtime::emit('notification_all_status_disabled', result, :tenant)
  end

  def csv_already_imported_warning
    result = {'status' => false, 'message' => 'Looks like the CSV file with this name has already been imported before.<br/> If you would like to re-import this file please'}
    GroovRealtime::emit('csv_already_imported_warning', result, :tenant)
  end

  def multiple_orders_scanning_count(orders)
    kits = OrderItem
      .joins(:product, order_item_kit_products: [:product_kit_skus])
      .where(
        order_id: orders.map(&:id), products: { is_kit: 1, kit_parsing: %w(individual)}
      )
      .select([
        'order_items.qty as order_item_qty', 'order_items.kit_split_qty',
        'order_items.kit_split_scanned_qty', 'order_items.kit_split',
        'product_kit_skus.qty as product_kit_skus_qty', 'order_id',
        'order_item_kit_products.scanned_qty as kit_product_scanned_qty',
        'kit_parsing', 'order_items.scanned_qty as order_item_scanned_qty',
        'is_kit', 'is_intangible', 'order_items.id', 'single_scanned_qty'
      ]).as_json

    single_kit_or_individual_items = OrderItem.joins(:product)
      .where(order_id: orders.map(&:id))
      .where(
        "(products.kit_parsing = 'single' AND products.is_kit IN (0,1) ) OR "\
        "(products.kit_parsing = 'individual' AND products.is_kit = 0 ) OR "\
        "(products.is_kit IS NULL ) OR "\
        "(products.kit_parsing = 'depends' AND products.is_kit IN (0,1) )"
      )
      .select([
        'is_kit', 'kit_parsing', 'order_items.qty as order_item_qty',
        'order_items.scanned_qty as order_item_scanned_qty', 'is_intangible',
        'order_items.id', 'single_scanned_qty', 'order_id'
      ]).as_json

    grouped_data = kits.push(*single_kit_or_individual_items).group_by { |oi| oi['order_id'] }

    orders_scanning_count = {scanned: 0, unscanned: 0}

    grouped_data.each do |order_id, order_data|
      orders_scanning_count[order_id] =
        order_data.reduce({scanned: 0, unscanned: 0}) do |tmp_hash, data_hash|
          update_grouped_order_date(tmp_hash, data_hash)
          tmp_hash
        end
    end

    orders_scanning_count
  end

  def add_activity_to_new_order(neworder, order_items, username)
    # order_items.each do |order_item|
    #   Order.create_new_order_item(neworder, order_item)
    # end
    order_items.each { |order_item| Order.create_new_order_item(neworder, order_item) }
    neworder.addactivity('Order duplicated', username)
  end

  def create_new_order_item(neworder, order_item)
    neworder_item = OrderItem.new
    neworder_item.order_id = neworder.id
    neworder_item.product_id = order_item.product_id
    neworder_item.qty = order_item.qty
    neworder_item.name = order_item.name
    neworder_item.price = order_item.price
    neworder_item.row_total = order_item.row_total
    neworder_item.save
  end

  def update_grouped_order_date(tmp_hash, data_hash)
    if data_hash['is_kit'] == 1
      case data_hash['kit_parsing']
      when 'single'
        tmp_hash[:unscanned] += (data_hash['order_item_qty'] - data_hash['order_item_scanned_qty'])
        tmp_hash[:scanned] += data_hash['order_item_scanned_qty']
      when 'individual'
        tmp_hash[:unscanned] += (
          data_hash['order_item_qty'] * data_hash['product_kit_skus_qty']
        ) - data_hash['kit_product_scanned_qty']
        tmp_hash[:scanned] += data_hash['kit_product_scanned_qty']
      when 'depends'
        if data_hash['kit_split']

          if data_hash['kit_split_qty'] > data_hash['kit_split_scanned_qty']
            tmp_hash[:unscanned] += (
              data_hash['kit_split_qty'] * data_hash['product_kit_skus_qty']
            ) - data_hash['kit_product_scanned_qty']
          end

          if data_hash['order_item_qty'] > data_hash['kit_split_qty']
            tmp_hash[:unscanned] += (
              data_hash['order_item_qty'] - data_hash['kit_split_qty']
            ) - (
              data_hash['order_item_scanned_qty'] - data_hash['kit_split_scanned_qty']
            )
          end

          tmp_hash[:scanned] += data_hash['kit_split_scanned_qty'] if data_hash['kit_split_qty'] > 0

          tmp_hash[:scanned] += data_hash['single_scanned_qty'] if data_hash['single_scanned_qty'] != 0
        else
          tmp_hash[:unscanned] += (data_hash['order_item_qty'] - data_hash['order_item_scanned_qty'])
          tmp_hash[:scanned] += data_hash['order_item_scanned_qty']
        end
      end
    else
      # for individual items
      tmp_hash[:unscanned] += (data_hash['order_item_qty'] - data_hash['order_item_scanned_qty'] rescue 0) unless data_hash['is_intangible'] == 1

      tmp_hash[:scanned] += data_hash['order_item_scanned_qty']
    end
  end

  def get_temp_increment_id
    temp_increment_ids = Order.where("increment_id LIKE 'GP-Manual-Order-%'").order(:increment_id).pluck(:increment_id)
    while true
      if temp_increment_ids.length.positive?
        next_inc_id = 'GP-Manual-Order-' + (get_last_temp_increment_id(temp_increment_ids) + 1).to_s
      else
        next_inc_id = 'GP-Manual-Order-1'
      end
      if !Order.find_by_increment_id(next_inc_id)
        break
      else
        temp_increment_ids << next_inc_id
      end
    end
    next_inc_id
  end

  def get_last_temp_increment_id(temp_increment_ids)
    inc_ids = []
    temp_increment_ids.each do |inc_id|
      inc_ids << inc_id.split('-').last.to_i
    end
    inc_ids.sort.last
  end
end
