class ExportSetting < ActiveRecord::Base
  attr_accessible :auto_email_export, :time_to_send_export_email, :send_export_email_on_mon,
   :send_export_email_on_tue, :send_export_email_on_wed, :send_export_email_on_thu,
   :send_export_email_on_fri, :send_export_email_on_sat, :send_export_email_on_sun, 
   :last_exported, :export_orders_option, :order_export_type, :order_export_email 

  after_save :scheduled_export

  def scheduled_export
    result = Hash.new
    changed_hash = self.changes
    if self.auto_email_export && !changed_hash[:time_to_send_export_email].nil?
      if self.should_export_orders_today
        job_scheduled = false
        date = DateTime.now
        general_settings = GeneralSetting.all.first
        while !job_scheduled do
          job_scheduled = general_settings.schedule_job(date, 
            self.time_to_send_export_email,'export_order')
          date = DateTime.now + 1.day
        end
      end
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
    start_time = nil
    end_time = nil
    if self.export_orders_option == 'on_same_day'
      start_time = Time.zone.now.beginning_of_day
    else
      unless self.last_exported.nil?
        start_time = self.last_exported
      else
        start_time = '2000-01-01 00:00:00'
      end
    end
    if start_time.nil?
      result['status'] = false
      result['messages'].push('We need a start and an end time')
    else
      orders = Order.where(scanned_on: start_time..Time.now)
      scanpack_settings = ScanPackSetting.all.first
      self.last_exported = Time.now
      self.save
      filename = 'groove-order-export-'+Time.now.to_s+'.csv'
      unless self.order_export_type == 'do_not_include'
        row_map = {
          :order_date =>'',
          :order_number => '',
          :barcode_with_lot => '',
          :barcode =>'',
          :lot_number =>'',
          :primary_sku =>'',
          :serial_number =>'',
          :product_name=>'',
          :packing_user =>'',
          :order_item_count => '',
          :scanned_date =>'',
          :warehouse_name =>''
        }
        CSV.open("#{Rails.root}/public/csv/#{filename}","w") do |csv|
          csv << row_map.keys
          orders.each do |order|
            order_items = order.order_items
            unless order_items.empty?
              previous_row = row_map.dup
              order_items.each do |order_item|
                if self.order_export_type == 'order_with_serial_lot'
                  unless order_item.product.primary_barcode.nil?
                    product = order_item.product
                    serials = OrderSerial.where(:product_id=>product.id)
                    unless serials.empty?
                      serials.each do |serial|
                        single_row = row_map.dup
                        single_row[:serial_number] = serial.serial
                        single_row[:order_number] = order_item.order.increment_id
                        single_row[:order_date] = order_item.order.order_placed_time
                        single_row[:scanned_date] = order_item.order.scanned_on
                        packing_user = nil
                        packing_user = User.find(order_item.order.packing_user_id) unless order_item.order.packing_user_id.blank?
                        unless packing_user.nil?
                          single_row[:packing_user] = packing_user.name + ' ('+packing_user.username+')'
                          single_row[:warehouse_name] =  order_item.product.primary_warehouse.inventory_warehouse.name unless order_item.product.primary_warehouse.nil? || order_item.product.primary_warehouse.inventory_warehouse.nil?
                        end
                        single_row[:barcode_with_lot] = order_item.product.primary_barcode
                        unless scanpack_settings.escape_string.nil?
                          barcode = order_item.product.primary_barcode
                          single_row[:barcode] = barcode.slice(0..(barcode.index(scanpack_settings.escape_string)-1)) unless barcode.index(scanpack_settings.escape_string).nil?
                          single_row[:lot_number] = barcode.slice(barcode.index(scanpack_settings.escape_string)..(barcode.length-1)) unless barcode.index(scanpack_settings.escape_string).nil?
                        end
                        single_row[:product_name] = order_item.product.name
                        single_row[:primary_sku] =  order_item.product.primary_sku
                        single_row[:order_item_count] = order_item.order.get_items_count

                        csv << single_row.values
                      end
                    else
                      unless scanpack_settings.escape_string.nil?
                        barcode = order_item.product.primary_barcode
                        lot_number = barcode.slice(barcode.index(scanpack_settings.escape_string)..(barcode.length-1)) unless barcode.index(scanpack_settings.escape_string).nil?
                        unless lot_number.nil?
                          single_row = row_map.dup
                          single_row[:order_number] = order_item.order.increment_id
                          single_row[:order_date] = order_item.order.order_placed_time
                          single_row[:scanned_date] = order_item.order.scanned_on
                          packing_user = nil
                          packing_user = User.find(order_item.order.packing_user_id) unless order_item.order.packing_user_id.blank?
                          unless packing_user.nil?
                            single_row[:packing_user] = packing_user.name + ' ('+packing_user.username+')'
                            single_row[:warehouse_name] =  order_item.product.primary_warehouse.inventory_warehouse.name unless order_item.product.primary_warehouse.nil? || order_item.product.primary_warehouse.inventory_warehouse.nil?
                          end
                          single_row[:barcode_with_lot] = order_item.product.primary_barcode
                          
                          single_row[:barcode] = barcode.slice(0..(barcode.index(scanpack_settings.escape_string)-1)) unless barcode.index(scanpack_settings.escape_string).nil?
                          single_row[:lot_number] = lot_number
                          single_row[:product_name] = order_item.product.name
                          single_row[:primary_sku] =  order_item.product.primary_sku
                          single_row[:order_item_count] = order_item.order.get_items_count

                          csv << single_row.values
                        end
                      end
                    end
                  else
                    next
                  end
                else
                  product = order_item.product
                  serials = OrderSerial.where(:product_id=>product.id)
                  unless serials.empty?
                    serials.each do |serial|
                      single_row = row_map.dup
                      single_row[:serial_number] = serial.serial
                      single_row[:order_number] = order_item.order.increment_id
                      single_row[:order_date] = order_item.order.order_placed_time
                      single_row[:scanned_date] = order_item.order.scanned_on
                      packing_user = nil
                      packing_user = User.find(order_item.order.packing_user_id) unless order_item.order.packing_user_id.blank?
                      unless packing_user.nil?
                        single_row[:packing_user] = packing_user.name + ' ('+packing_user.username+')'
                        single_row[:warehouse_name] =  order_item.product.primary_warehouse.inventory_warehouse.name unless order_item.product.primary_warehouse.nil? || order_item.product.primary_warehouse.inventory_warehouse.nil?
                      end
                      single_row[:barcode_with_lot] = order_item.product.primary_barcode
                      unless scanpack_settings.escape_string.nil?
                        barcode = order_item.product.primary_barcode
                        single_row[:barcode] = barcode.slice(0..(barcode.index(scanpack_settings.escape_string)-1)) unless barcode.index(scanpack_settings.escape_string).nil?
                        single_row[:lot_number] = barcode.slice(barcode.index(scanpack_settings.escape_string)..(barcode.length-1)) unless barcode.index(scanpack_settings.escape_string).nil?
                      end
                      single_row[:product_name] = order_item.product.name
                      single_row[:primary_sku] =  order_item.product.primary_sku
                      single_row[:order_item_count] = order_item.order.get_items_count

                      if (single_row[:serial_number] == previous_row[:serial_number] && 
                        single_row[:order_number] == previous_row[:order_number] &&
                        single_row[:scanned_date] == previous_row[:scanned_date] &&
                        single_row[:packing_user] == previous_row[:packing_user] &&
                        single_row[:warehouse_name] == previous_row[:warehouse_name] &&
                        single_row[:barcode_with_lot] == previous_row[:barcode_with_lot] &&
                        single_row[:barcode] == previous_row[:barcode] &&
                        single_row[:lot_number] == previous_row[:lot_number] &&
                        single_row[:product_name] == previous_row[:product_name] &&
                        single_row[:primary_sku] == previous_row[:primary_sku])
                        single_row[:order_item_count] = single_row[:order_item_count].to_i + previous_row[:order_item_count].to_i
                      end
                      previous_row = single_row
                      csv << single_row.values
                    end
                  else
                    single_row = row_map.dup
                    single_row[:order_number] = order_item.order.increment_id
                    single_row[:order_date] = order_item.order.order_placed_time
                    single_row[:scanned_date] = order_item.order.scanned_on
                    packing_user = nil
                    packing_user = User.find(order_item.order.packing_user_id) unless order_item.order.packing_user_id.blank?
                    unless packing_user.nil?
                      single_row[:packing_user] = packing_user.name + ' ('+packing_user.username+')'
                      single_row[:warehouse_name] =  order_item.product.primary_warehouse.inventory_warehouse.name unless order_item.product.primary_warehouse.nil? || order_item.product.primary_warehouse.inventory_warehouse.nil?
                    end
                    single_row[:barcode_with_lot] = order_item.product.primary_barcode
                    unless scanpack_settings.escape_string.nil?
                      barcode = order_item.product.primary_barcode
                      single_row[:barcode] = barcode.slice(0..(barcode.index(scanpack_settings.escape_string)-1)) unless barcode.index(scanpack_settings.escape_string).nil?
                      single_row[:lot_number] = barcode.slice(barcode.index(scanpack_settings.escape_string)..(barcode.length-1)) unless barcode.index(scanpack_settings.escape_string).nil?
                    end
                    single_row[:product_name] = order_item.product.name
                    single_row[:primary_sku] =  order_item.product.primary_sku
                    single_row[:order_item_count] = order_item.order.get_items_count

                    if (single_row[:order_number] == previous_row[:order_number] &&
                      single_row[:scanned_date] == previous_row[:scanned_date] &&
                      single_row[:packing_user] == previous_row[:packing_user] &&
                      single_row[:warehouse_name] == previous_row[:warehouse_name] &&
                      single_row[:barcode_with_lot] == previous_row[:barcode_with_lot] &&
                      single_row[:barcode] == previous_row[:barcode] &&
                      single_row[:lot_number] == previous_row[:lot_number] &&
                      single_row[:product_name] == previous_row[:product_name] &&
                      single_row[:primary_sku] == previous_row[:primary_sku])
                      single_row[:order_item_count] = single_row[:order_item_count].to_i + previous_row[:order_item_count].to_i
                      # previous_row = single_row
                    end
                    previous_row = single_row
                    csv << single_row.values
                  end
                end
              end
            end
          end
        end
      else
        row_map = {
          :order_date =>'',
          :order_number => '',
          :packing_user =>'',
          :scanned_date =>''
        }
        CSV.open("#{Rails.root}/public/csv/#{filename}","w") do |csv|
          csv << row_map.keys
          orders.each do |order|
            single_row = row_map.dup
            single_row[:order_number] = order.increment_id
            single_row[:order_date] = order.order_placed_time
            single_row[:scanned_date] = order.scanned_on
            packing_user = nil
            packing_user = User.find(order.packing_user_id) unless order.packing_user_id.blank?
            unless packing_user.nil?
              single_row[:packing_user] = packing_user.name + ' ('+packing_user.username+')'
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
end
