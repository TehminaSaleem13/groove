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
    unless self.manual_export
      if self.export_orders_option == 'on_same_day'
        start_time = Time.now.beginning_of_day
        end_time = Time.now
      else
        unless self.last_exported.nil?
          start_time = self.last_exported
          end_time = Time.now
        else
          start_time = '2000-01-01 00:00:00'
          end_time = Time.now
        end
      end
    else
      start_time = self.start_time.beginning_of_day
      end_time = self.end_time.end_of_day
    end
    
    if start_time.nil?
      result['status'] = false
      result['messages'].push('We need a start and an end time')
    else
      orders = Order.where(scanned_on: start_time..end_time)
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
        order_hash_array = []
        order_hash = {:order_date=>"order_date", :order_number=>"order_number",
             :barcode_with_lot=>"barcode_with_lot", :barcode=>"barcode",
             :lot_number=>"lot_number", :primary_sku=>"primary_sku",
             :serial_number=>"serial_number", :product_name=>"product_name",
             :packing_user=>"packing_user", :order_item_count=>"order_item_count",
             :scanned_date=>"scanned_date", :warehouse_name=>"warehouse_name"}
        order_hash_array.push(order_hash)
        orders.each do |order|
          order_items = order.order_items
          unless order_items.empty?
            order_items.each do |order_item|
              serials = OrderSerial.where(:product_id=>order_item.product.id, :order_id=>order_item.order.id)
              if self.order_export_type == 'order_with_serial_lot'
                lot_number = order_item.get_lot_number(order_item.product.primary_barcode)
                unless serials.empty? && lot_number.nil?
                  unless serials.empty?
                    serials.each do |serial|
                      single_row = row_map.dup
                      single_row = calculate_row_data(single_row, order_item)
                      single_row[:serial_number] = serial.serial
                      single_row[:order_item_count] = 1
                      
                      order_hash = {:order_date=>single_row[:order_date], :order_number=>single_row[:order_number],
                       :barcode_with_lot=>single_row[:barcode_with_lot], :barcode=>single_row[:barcode],
                       :lot_number=>single_row[:lot_number], :primary_sku=>single_row[:primary_sku],
                       :serial_number=>single_row[:serial_number], :product_name=>single_row[:product_name],
                       :packing_user=>single_row[:packing_user], :order_item_count=>single_row[:order_item_count],
                       :scanned_date=>single_row[:scanned_date], :warehouse_name=>single_row[:warehouse_name]}
                      order_hash_array.push(order_hash)
                    end
                  else
                    unless lot_number.nil?
                      single_row = row_map.dup
                      single_row = calculate_row_data(single_row, order_item)
                      single_row[:order_item_count] = order_item.qty

                      order_hash = {:order_date=>single_row[:order_date], :order_number=>single_row[:order_number],
                       :barcode_with_lot=>single_row[:barcode_with_lot], :barcode=>single_row[:barcode],
                       :lot_number=>single_row[:lot_number], :primary_sku=>single_row[:primary_sku],
                       :serial_number=>single_row[:serial_number], :product_name=>single_row[:product_name],
                       :packing_user=>single_row[:packing_user], :order_item_count=>single_row[:order_item_count],
                       :scanned_date=>single_row[:scanned_date], :warehouse_name=>single_row[:warehouse_name]}
                      order_hash_array.push(order_hash)
                    end
                  end
                else
                  next
                end
              else
                unless serials.empty?
                  serials.each do |serial|
                    single_row = row_map.dup
                    single_row = calculate_row_data(single_row, order_item)
                    single_row[:serial_number] = serial.serial
                    single_row[:order_item_count] = 1
                    
                    duplicate_orders = order_hash_array.select {|duplicate_order| duplicate_order[:order_number] == single_row[:order_number] && duplicate_order[:primary_sku] == single_row[:primary_sku] && duplicate_order[:serial_number] == single_row[:serial_number]}                      
                    unless duplicate_orders.empty?
                      duplicate_order = duplicate_orders.first
                      duplicate_order[:order_item_count] = duplicate_order[:order_item_count].to_i + single_row[:order_item_count].to_i
                    else
                      order_hash = {:order_date=>single_row[:order_date], :order_number=>single_row[:order_number],
                       :barcode_with_lot=>single_row[:barcode_with_lot], :barcode=>single_row[:barcode],
                       :lot_number=>single_row[:lot_number], :primary_sku=>single_row[:primary_sku],
                       :serial_number=>single_row[:serial_number], :product_name=>single_row[:product_name],
                       :packing_user=>single_row[:packing_user], :order_item_count=>single_row[:order_item_count],
                       :scanned_date=>single_row[:scanned_date], :warehouse_name=>single_row[:warehouse_name]}
                      order_hash_array.push(order_hash)
                    end
                  end
                else
                  single_row = row_map.dup
                  single_row = calculate_row_data(single_row, order_item)
                  single_row[:order_item_count] = order_item.qty
                  
                  duplicate_orders = order_hash_array.select {|duplicate_order| duplicate_order[:order_number] == single_row[:order_number] && duplicate_order[:primary_sku] == single_row[:primary_sku]}                      
                  unless duplicate_orders.empty?
                    duplicate_order = duplicate_orders.first
                    duplicate_order[:order_item_count] = duplicate_order[:order_item_count].to_i + single_row[:order_item_count].to_i
                  else
                    order_hash = {:order_date=>single_row[:order_date], :order_number=>single_row[:order_number],
                     :barcode_with_lot=>single_row[:barcode_with_lot], :barcode=>single_row[:barcode],
                     :lot_number=>single_row[:lot_number], :primary_sku=>single_row[:primary_sku],
                     :serial_number=>single_row[:serial_number], :product_name=>single_row[:product_name],
                     :packing_user=>single_row[:packing_user], :order_item_count=>single_row[:order_item_count],
                     :scanned_date=>single_row[:scanned_date], :warehouse_name=>single_row[:warehouse_name]}
                    order_hash_array.push(order_hash)
                  end
                end
              end
            end
          end
        end
        
        CSV.open("#{Rails.root}/public/csv/#{filename}","w") do |csv|
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
              :order_date =>'',
              :order_number => '',
              :barcode =>'',
              :primary_sku =>'',
              :product_name=>'',
              :packing_user =>'',
              :order_item_count => '',
              :scanned_date =>'',
              :warehouse_name =>''
            }
          elsif show_serial_number==false && show_lot_number==true
            csv_row_map = {
              :order_date =>'',
              :order_number => '',
              :barcode_with_lot => '',
              :barcode =>'',
              :lot_number =>'',
              :primary_sku =>'',
              :product_name=>'',
              :packing_user =>'',
              :order_item_count => '',
              :scanned_date =>'',
              :warehouse_name =>''
            }
          elsif show_serial_number==true && show_lot_number==false
            csv_row_map = {
              :order_date =>'',
              :order_number => '',
              :barcode =>'',
              :primary_sku =>'',
              :serial_number =>'',
              :product_name=>'',
              :packing_user =>'',
              :order_item_count => '',
              :scanned_date =>'',
              :warehouse_name =>''
            }
          else
            csv_row_map = {
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
          :order_date =>'',
          :order_number => '',
          :scanned_qty => '',
          :packing_user =>'',
          :scanned_date =>'',
          :click_scanned_qty =>''
        }
        CSV.open("#{Rails.root}/public/csv/#{filename}","w") do |csv|
          csv << row_map.keys
          orders.each do |order|
            single_row = row_map.dup
            single_row[:order_number] = order.increment_id
            single_row[:scanned_qty] = order.scanned_items_count
            single_row[:order_date] = order.order_placed_time
            single_row[:scanned_date] = order.scanned_on
            packing_user = nil
            packing_user = User.find(order.packing_user_id) unless order.packing_user_id.blank?
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

  def calculate_row_data(single_row, order_item)
    single_row[:order_number] = order_item.order.increment_id
    single_row[:order_date] = order_item.order.order_placed_time
    single_row[:scanned_date] = order_item.order.scanned_on
    packing_user = nil
    packing_user = User.find(order_item.order.packing_user_id) unless order_item.order.packing_user_id.blank?
    unless packing_user.nil?
      single_row[:packing_user] = packing_user.name + ' ('+packing_user.username+')'
      single_row[:warehouse_name] =  order_item.product.primary_warehouse.inventory_warehouse.name unless order_item.product.primary_warehouse.nil? || order_item.product.primary_warehouse.inventory_warehouse.nil?
    end
    single_row[:lot_number] = order_item.get_lot_number(order_item.product.primary_barcode)
    single_row[:barcode_with_lot] = order_item.get_barcode_with_lotnumber(order_item.product.primary_barcode,single_row[:lot_number]) unless single_row[:lot_number].nil?
    single_row[:barcode] = order_item.product.primary_barcode
    single_row[:product_name] = order_item.product.name
    single_row[:primary_sku] =  order_item.product.primary_sku
    # single_row[:order_item_count] = order_item.qty

    single_row
  end
end
