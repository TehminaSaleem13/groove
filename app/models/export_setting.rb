class ExportSetting < ActiveRecord::Base
  attr_accessible :auto_email_export, :time_to_send_export_email, :send_export_email_on_mon,
                  :send_export_email_on_tue, :send_export_email_on_wed, :send_export_email_on_thu,
                  :send_export_email_on_fri, :send_export_email_on_sat, :send_export_email_on_sun,
                  :last_exported, :export_orders_option, :order_export_type, :order_export_email,
                  :start_time, :end_time, :manual_export

  after_save :scheduled_export

  def scheduled_export
    result = Hash.new
    changed_hash = self.changes
    if self.auto_email_export && !changed_hash[:time_to_send_export_email].nil? && !self.order_export_email.blank?
      job_scheduled = false
      date = DateTime.now
      general_settings = GeneralSetting.all.first
      for i in 0..6
        job_scheduled = general_settings.schedule_job(date,
                                                      self.time_to_send_export_email, 'export_order')
        date = date + 1.day
        break if job_scheduled
      end
    else
      tenant = Apartment::Tenant.current
      Delayed::Job.where(queue: "order_export_email_scheduled_#{tenant}").destroy_all
    end
  end

  def should_export_orders_today
    day = DateTime.now.strftime("%A")
    result = false
    if day=='Sunday' && self.send_export_email_on_sun
      result = true
    elsif day=='Monday' && self.send_export_email_on_mon
      result = true
    elsif day=='Tuesday' && self.send_export_email_on_tue
      result = true
    elsif day=='Wednesday' && self.send_export_email_on_wed
      result = true
    elsif day=='Thursday' && self.send_export_email_on_thu
      result = true
    elsif day=='Friday' && self.send_export_email_on_fri
      result = true
    elsif day=='Saturday' && self.send_export_email_on_sat
      result = true
    end
    result
  end

  def should_export_orders(date)
    day = date.strftime("%A")
    result = false
    if day=='Sunday' && self.send_export_email_on_sun
      result = true
    elsif day=='Monday' && self.send_export_email_on_mon
      result = true
    elsif day=='Tuesday' && self.send_export_email_on_tue
      result = true
    elsif day=='Wednesday' && self.send_export_email_on_wed
      result = true
    elsif day=='Thursday' && self.send_export_email_on_thu
      result = true
    elsif day=='Friday' && self.send_export_email_on_fri
      result = true
    elsif day=='Saturday' && self.send_export_email_on_sat
      result = true
    end
    result
  end

  def export_data
    require 'csv'
    result = Hash.new
    result['status'] = true
    result['messages'] = []
    start_time, end_time = get_start_and_end_time
    if start_time.nil?
      result['status'] = false
      result['messages'].push('We need a start and an end time')
    else
      orders = Order.where(scanned_on: start_time..end_time)
      scanpack_settings = ScanPackSetting.all.first
      self.last_exported = Time.zone.now
      self.save
      filename = 'groove-order-export-'+Time.now.to_s+'.csv'
      unless self.order_export_type == 'do_not_include'
        row_map = {
          :order_date => '',
          :order_number => '',
          :scanned_by_status_change => '',
          :scan_order => '',
          :barcode_with_lot => '',
          :barcode => '',
          :lot_number => '',
          :primary_sku => '',
          :part_sku => '',
          :serial_number => '',
          :product_name => '',
          :kit_name => '',
          :item_sale_price => '',
          :customer_name => '',
          :address1 => '',
          :address2 => '',
          :city => '',
          :state => '',
          :zip => '',
          :packing_user => '',
          :order_item_count => '',
          :scanned_date => '',
          :warehouse_name => ''
        }
        order_hash_array = []
        order_hash = { :order_date => "order_date", :order_number => "order_number",
          :scanned_by_status_change => "scanned_by_status_change",
          :scan_order => "scan_order", :barcode_with_lot => "barcode_with_lot", 
          :barcode => "barcode", :lot_number => "lot_number", :primary_sku => "primary_sku",
          :part_sku =>  "part_sku", :serial_number => "serial_number", 
          :product_name => "product_name", :packing_user => "packing_user", 
          :order_item_count => "order_item_count", :scanned_date => "scanned_date", 
          :warehouse_name => "warehouse_name", :item_sale_price => "item_sale_price", 
          :kit_name => "kit_name", :customer_name => "customer_name", :address1 => "address1", 
          :address2 => "address2", :city => "city", :state => "state", :zip => "zip" }
        order_hash_array.push(order_hash)
        orders.each do |order|
          order_items = order.order_items
          unless order_items.empty?
            order_hash_item_array = []
            order_items.each do |order_item|
              if self.order_export_type == 'order_with_serial_lot'
                order_item_serial_lots = OrderItemOrderSerialProductLot.where(order_item_id: order_item.id)
                unless order_item_serial_lots.empty?
                  order_item_serial_lots.each do |order_item_serial_lot|
                    unless order_item_serial_lot.order_serial.nil? && order_item_serial_lot.product_lot.nil?
                      product_lot = order_item_serial_lot.product_lot unless order_item_serial_lot.product_lot.nil?
                      order_serial = order_item_serial_lot.order_serial unless order_item_serial_lot.order_serial.nil?
                      (1..order_item_serial_lot.qty).each do
                        single_row = row_map.dup
                        single_row = calculate_row_data(single_row, order_item)
                        single_row[:order_item_count] = 1
                        unless product_lot.nil?
                          lot_number = product_lot.lot_number
                          single_row[:lot_number] = lot_number
                          single_row[:barcode_with_lot] = order_item.get_barcode_with_lotnumber(order_item.product.primary_barcode, single_row[:lot_number]) unless single_row[:lot_number].nil?
                        else
                          single_row[:lot_number] = ''
                          single_row[:barcode_with_lot] = ''
                        end
                        unless order_serial.nil?
                          if order_serial.product.is_kit == 0 && order_item.product.is_kit == 1
                            single_row[:part_sku] = order_serial.product.primary_sku
                            single_row[:product_name] = order_serial.product.name
                            unless order_serial.product.order_items.empty?
                              single_row[:item_sale_price] = order_serial.product.order_items.first.price
                            else
                              single_row[:item_sale_price] = 0.0
                            end
                          end
                          single_row[:serial_number] = order_serial.serial
                          serials = OrderSerial.where(order_id: order_item.order.id)
                          serials.each_with_index do |serial, index|
                            if serial.serial == order_serial.serial
                              single_row[:scan_order] = (index+1).to_s
                              break
                            end
                          end
                        else
                          single_row[:serial_number] = ''
                        end
                        
                        order_hash = {:order_date => single_row[:order_date], :order_number => single_row[:order_number],
                          :scanned_by_status_change => single_row[:scanned_by_status_change],
                          :barcode_with_lot => single_row[:barcode_with_lot], :barcode => single_row[:barcode],
                          :lot_number => single_row[:lot_number], :primary_sku => single_row[:primary_sku],
                          :part_sku => single_row[:part_sku], :serial_number => single_row[:serial_number], 
                          :product_name => single_row[:product_name], :packing_user => single_row[:packing_user], 
                          :order_item_count => single_row[:order_item_count], :scanned_date => single_row[:scanned_date], 
                          :warehouse_name => single_row[:warehouse_name], :item_sale_price => single_row[:item_sale_price], 
                          :scan_order => single_row[:scan_order], :kit_name => single_row[:kit_name], 
                          :customer_name => single_row[:customer_name], :address1 => single_row[:address1], 
                          :address2 => single_row[:address2], :city => single_row[:city], 
                          :state => single_row[:state], :zip => single_row[:zip]}
                        order_hash_item_array.push(order_hash)
                      end
                    else
                      next
                    end
                  end
                end
              else
                order_item_serial_lots = OrderItemOrderSerialProductLot.where(order_item_id: order_item.id)
                unless order_item_serial_lots.empty?
                  qty_with_lot_serial = 0
                  order_item_serial_lots.each do |order_item_serial_lot|
                    product_lot = order_item_serial_lot.product_lot unless order_item_serial_lot.product_lot.nil?
                    order_serial = order_item_serial_lot.order_serial unless order_item_serial_lot.order_serial.nil?
                    single_row = row_map.dup
                    single_row = calculate_row_data(single_row, order_item)
                    single_row[:order_item_count] = order_item_serial_lot.qty
                    qty_with_lot_serial += order_item_serial_lot.qty
                    unless product_lot.nil?
                      lot_number = product_lot.lot_number
                      single_row[:lot_number] = lot_number
                      single_row[:barcode_with_lot] = order_item.get_barcode_with_lotnumber(order_item.product.primary_barcode, single_row[:lot_number]) unless single_row[:lot_number].nil?
                    else
                      single_row[:lot_number] = ''
                      single_row[:barcode_with_lot] = ''
                    end
                    unless order_serial.nil?
                      if order_serial.product.is_kit == 0 && order_item.product.is_kit == 1
                        single_row[:part_sku] = order_serial.product.primary_sku
                        single_row[:product_name] = order_serial.product.name
                        unless order_serial.product.order_items.empty?
                          single_row[:item_sale_price] = order_serial.product.order_items.first.price
                        else
                          single_row[:item_sale_price] = 0.0
                        end
                      end
                      single_row[:serial_number] = order_serial.serial
                      serials = OrderSerial.where(order_id: order_item.order.id)
                      serials.each_with_index do |serial, index|
                        if serial.serial == order_serial.serial
                          single_row[:scan_order] = (index+1).to_s
                          break
                        end
                      end
                    else
                      single_row[:serial_number] = ''
                    end
                    
                    order_hash = {:order_date => single_row[:order_date], :order_number => single_row[:order_number],
                      :scanned_by_status_change => single_row[:scanned_by_status_change],
                      :barcode_with_lot => single_row[:barcode_with_lot], :barcode => single_row[:barcode],
                      :lot_number => single_row[:lot_number], :primary_sku => single_row[:primary_sku],
                      :part_sku => single_row[:part_sku], :serial_number => single_row[:serial_number], 
                      :product_name => single_row[:product_name], :packing_user => single_row[:packing_user], 
                      :order_item_count => single_row[:order_item_count], :scanned_date => single_row[:scanned_date], 
                      :warehouse_name => single_row[:warehouse_name], :item_sale_price => single_row[:item_sale_price], 
                      :scan_order => single_row[:scan_order], :kit_name => single_row[:kit_name], 
                      :customer_name => single_row[:customer_name], :address1 => single_row[:address1], 
                      :address2 => single_row[:address2], :city => single_row[:city], 
                      :state => single_row[:state], :zip => single_row[:zip]}
                    order_hash_item_array.push(order_hash)
                  end
                  if order_item.qty > qty_with_lot_serial
                    single_row = row_map.dup
                    single_row = calculate_row_data(single_row, order_item)
                    single_row[:order_item_count] = order_item.qty - qty_with_lot_serial
                    single_row[:lot_number] = ''
                    single_row[:barcode_with_lot] = ''
                    single_row[:serial_number] = ''
                    single_row[:scan_order] = ''
                    order_hash = {:order_date => single_row[:order_date], :order_number => single_row[:order_number],
                      :scanned_by_status_change => single_row[:scanned_by_status_change],
                      :barcode_with_lot => single_row[:barcode_with_lot], :barcode => single_row[:barcode],
                      :lot_number => single_row[:lot_number], :primary_sku => single_row[:primary_sku], 
                      :part_sku => single_row[:part_sku], :serial_number => single_row[:serial_number], 
                      :product_name => single_row[:product_name], :packing_user => single_row[:packing_user], 
                      :order_item_count => single_row[:order_item_count], :scanned_date => single_row[:scanned_date], 
                      :warehouse_name => single_row[:warehouse_name], :item_sale_price => single_row[:item_sale_price], 
                      :scan_order => single_row[:scan_order], :kit_name => single_row[:kit_name], 
                      :customer_name => single_row[:customer_name], :address1 => single_row[:address1], 
                      :address2 => single_row[:address2], :city => single_row[:city], 
                      :state => single_row[:state], :zip => single_row[:zip]}
                    order_hash_item_array.push(order_hash)
                  end
                else
                  single_row = row_map.dup
                  single_row = calculate_row_data(single_row, order_item)
                  single_row[:order_item_count] = order_item.qty
                  single_row[:lot_number] = ''
                  single_row[:barcode_with_lot] = ''
                  single_row[:serial_number] = ''
                  single_row[:scan_order] = ''
                  order_hash = {:order_date => single_row[:order_date], :order_number => single_row[:order_number],
                    :scanned_by_status_change => single_row[:scanned_by_status_change],
                    :barcode_with_lot => single_row[:barcode_with_lot], :barcode => single_row[:barcode],
                    :lot_number => single_row[:lot_number], :primary_sku => single_row[:primary_sku], 
                    :part_sku => single_row[:part_sku], :serial_number => single_row[:serial_number], 
                    :scan_order => single_row[:scan_order], :product_name => single_row[:product_name], 
                    :packing_user => single_row[:packing_user], :order_item_count => single_row[:order_item_count], 
                    :scanned_date => single_row[:scanned_date], :warehouse_name => single_row[:warehouse_name], 
                    :item_sale_price => single_row[:item_sale_price], :kit_name => single_row[:kit_name], 
                    :customer_name => single_row[:customer_name], :address1 => single_row[:address1], 
                    :address2 => single_row[:address2], :city => single_row[:city], 
                    :state => single_row[:state], :zip => single_row[:zip]}
                  order_hash_item_array.push(order_hash)
                end
              end
            end
            ordered_hash_item_array = order_hash_item_array.sort_by { |hsh| hsh[:scan_order].to_i }
            ordered_hash_item_array.each do |hsh|
              order_hash_array.push(hsh)
            end
          end
        end

        CSV.open("#{Rails.root}/public/csv/#{filename}", "w") do |csv|
          show_lot_number = false
          show_serial_number = false
          for i in 1..order_hash_array.size-1
            unless order_hash_array[i][:lot_number].nil? || order_hash_array[i][:lot_number]==""
              show_lot_number = true
              break
            end
          end

          for i in 1..order_hash_array.size-1
            unless order_hash_array[i][:serial_number].nil? || order_hash_array[i][:serial_number]==""
              show_serial_number = true
              break
            end
          end

          if show_serial_number==false && show_lot_number==false
            csv_row_map = {
              :order_date => '',
              :order_number => '',
              :scanned_by_status_change => '',
              :barcode => '',
              :primary_sku => '',
              :product_name => '',
              :kit_name => '',
              :item_sale_price => '',
              :customer_name => '',
              :address1 => '',
              :address2 => '',
              :city => '',
              :state => '',
              :zip => '',
              :packing_user => '',
              :order_item_count => '',
              :scanned_date => '',
              :warehouse_name => ''
            }
          elsif show_serial_number==false && show_lot_number==true
            csv_row_map = {
              :order_date => '',
              :order_number => '',
              :scanned_by_status_change => '',
              :barcode_with_lot => '',
              :barcode => '',
              :lot_number => '',
              :primary_sku => '',
              :part_sku => '',
              :product_name => '',
              :kit_name => '',
              :item_sale_price => '',
              :customer_name => '',
              :address1 => '',
              :address2 => '',
              :city => '',
              :state => '',
              :zip => '',
              :packing_user => '',
              :order_item_count => '',
              :scanned_date => '',
              :warehouse_name => ''
            }
          elsif show_serial_number==true && show_lot_number==false
            csv_row_map = {
              :order_date => '',
              :order_number => '',
              :scanned_by_status_change => '',
              :scan_order => '',
              :barcode => '',
              :primary_sku => '',
              :part_sku => '',
              :serial_number => '',
              :product_name => '',
              :kit_name => '',
              :item_sale_price => '',
              :customer_name => '',
              :address1 => '',
              :address2 => '',
              :city => '',
              :state => '',
              :zip => '',
              :packing_user => '',
              :order_item_count => '',
              :scanned_date => '',
              :warehouse_name => ''
            }
          else
            csv_row_map = {
              :order_date => '',
              :order_number => '',
              :scanned_by_status_change => '',
              :scan_order => '',
              :barcode_with_lot => '',
              :barcode => '',
              :lot_number => '',
              :primary_sku => '',
              :part_sku => '',
              :serial_number => '',
              :product_name => '',
              :kit_name => '',
              :item_sale_price => '',
              :customer_name => '',
              :address1 => '',
              :address2 => '',
              :city => '',
              :state => '',
              :zip => '',
              :packing_user => '',
              :order_item_count => '',
              :scanned_date => '',
              :warehouse_name => ''
            }
          end

          order_hash_array.each do |order_hash|
            single_row = csv_row_map.dup
            for i in 0..single_row.size-1
              single_row[csv_row_map.keys[i]] = order_hash[csv_row_map.keys[i]]
            end
            csv << single_row.values
          end
        end
      else
        row_map = {
          :order_date => '',
          :order_number => '',
          :scanned_by_status_change => '',
          :scanned_qty => '',
          :packing_user => '',
          :scanned_date => '',
          :click_scanned_qty => ''
        }
        CSV.open("#{Rails.root}/public/csv/#{filename}", "w") do |csv|
          csv << row_map.keys
          orders.each do |order|
            single_row = row_map.dup
            single_row[:order_number] = order.increment_id
            single_row[:scanned_by_status_change] = order.scanned_by_status_change
            single_row[:scanned_qty] = order.scanned_items_count
            single_row[:order_date] = order.order_placed_time
            single_row[:scanned_date] = order.scanned_on
            packing_user = nil
            packing_user = User.find_by_id(order.packing_user_id) unless order.packing_user_id.blank?
            unless packing_user.nil?
              single_row[:packing_user] = packing_user.name + ' ('+packing_user.username+')'
            end
            order_items = order.order_items
            unless order_items.empty?
              single_row[:click_scanned_qty] = 0
              order_items.each do |order_item|
                single_row[:click_scanned_qty] += order_item.clicked_qty
              end
            end
            csv << single_row.values
          end
        end
      end
    end

    unless result['status']
      data = CSV.generate do |csv|
        csv << result['messages']
      end
      filename = 'error.csv'
    end
    filename
  end

  def get_start_and_end_time
    start_time = nil
    end_time = nil
    unless self.manual_export
      if self.export_orders_option == 'on_same_day'
        start_time = Time.zone.now.beginning_of_day
        end_time = Time.zone.now
      else
        unless self.last_exported.nil?
          start_time = self.last_exported
          end_time = Time.zone.now
        else
          start_time = '2000-01-01 00:00:00'
          end_time = Time.zone.now
        end
      end
    else
      start_time = self.start_time.beginning_of_day
      end_time = self.end_time.end_of_day
    end
    return start_time, end_time
  end

  def calculate_row_data(single_row, order_item)
    single_row[:order_number] = order_item.order.increment_id
    single_row[:order_date] = order_item.order.order_placed_time
    single_row[:scanned_by_status_change] = order_item.order.scanned_by_status_change
    single_row[:scanned_date] = order_item.order.scanned_on
    single_row[:address1] = order_item.order.address_1
    single_row[:address2] = order_item.order.address_2
    single_row[:city] = order_item.order.city
    single_row[:state] = order_item.order.state
    single_row[:zip] = order_item.order.postcode
    single_row[:customer_name] = [order_item.order.firstname, order_item.order.lastname].join(' ')
    packing_user = nil
    packing_user = User.find(order_item.order.packing_user_id) unless order_item.order.packing_user_id.blank?
    unless packing_user.nil?
      single_row[:packing_user] = packing_user.name + ' ('+packing_user.username+')'
      single_row[:warehouse_name] = order_item.product.primary_warehouse.inventory_warehouse.name unless order_item.product.primary_warehouse.nil? || order_item.product.primary_warehouse.inventory_warehouse.nil?
    end
    single_row[:barcode] = order_item.product.primary_barcode
    if order_item.product.is_kit == 1
      single_row[:kit_name] = order_item.product.name
    else
      single_row[:product_name] = order_item.product.name
    end
    single_row[:primary_sku] = order_item.product.primary_sku
    single_row[:item_sale_price] = order_item.price
    single_row
  end
end
