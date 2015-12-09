module ScanPack
  class Base
    def can_order_be_scanned
      #result = false
      #max_shipments = AccessRestriction.order("created_at").last.num_shipments
      #total_shipments = AccessRestriction.order("created_at").last.total_scanned_shipments
      #if total_shipments < max_shipments
      #  result = true
      #else
      #  result = false
      #end
      #result
      true
    end

    def order_details_and_next_item
      @single_order.reload
      data = @single_order.attributes
      data['unscanned_items'] = @single_order.get_unscanned_items
      data['scanned_items'] = @single_order.get_scanned_items
      unless data['unscanned_items'].length == 0
        unless @session[:most_recent_scanned_products].nil?
          @session[:most_recent_scanned_products].reverse!.each do |scanned_product_id|
            data['unscanned_items'].each do |unscanned_item|
              if @session[:parent_order_item] && @session[:parent_order_item] == unscanned_item['order_item_id']
                @session[:parent_order_item] = false
                if unscanned_item['product_type'] == 'individual' && !unscanned_item['child_items'].empty?
                  data['next_item'] = unscanned_item['child_items'].first.clone
                  break
                end
              elsif unscanned_item['product_type'] == 'single' &&
                scanned_product_id == unscanned_item['product_id'] &&
                unscanned_item['scanned_qty'] + unscanned_item['qty_remaining'] > 0
                data['next_item'] = unscanned_item.clone
                break
              elsif unscanned_item['product_type'] == 'individual'
                unscanned_item['child_items'].each do |child_item|
                  if child_item['product_id'] == scanned_product_id
                    data['next_item'] = child_item.clone
                    break
                  end
                end
                break if !data['next_item'].nil?
              end
            end
            break if !data['next_item'].nil?
          end
        end
        if data['next_item'].nil?
          if data['unscanned_items'].first['product_type'] == 'single'
            data['next_item'] = data['unscanned_items'].first.clone
          elsif data['unscanned_items'].first['product_type'] == 'individual'
            data['next_item'] = data['unscanned_items'].first['child_items'].first.clone unless data['unscanned_items'].first['child_items'].empty?
          end
        end
        data['next_item']['qty'] = data['next_item']['scanned_qty'] + data['next_item']['qty_remaining']
      end

      return data
    end

    def generate_packing_slip(order)
      result = Hash.new
      result['status'] = false
      if GeneralSetting.get_packing_slip_size == '4 x 6'
        @page_height = '6'
        @page_width = '4'
      else
        @page_height = '11'
        @page_width = '8.5'
      end
      @size = GeneralSetting.get_packing_slip_size
      @orientation = GeneralSetting.get_packing_slip_orientation
      # Earlier this was @result so it messed up with @result from the method.
      # Changed it to @slip_data_hash
      @slip_data_hash = Hash.new
      @slip_data_hash['data'] = Hash.new
      @slip_data_hash['data']['packing_slip_file_paths'] = []

      if @orientation == 'landscape'
        @page_height = @page_height.to_f/2
        @page_height = @page_height.to_s
      end
      @header = ''

      @file_name = Apartment::Tenant.current+Time.now.strftime('%d_%b_%Y_%I__%M_%p')
      orders = []

      @single_order = Order.find(order.id)
      unless @single_order.nil?
        orders.push({id: @single_order.id, increment_id: @single_order.increment_id})
      end
      unless orders.empty?
        GenerateBarcode.where('updated_at < ?', 24.hours.ago).delete_all
        @generate_barcode = GenerateBarcode.new
        @generate_barcode.user_id = @current_user.id
        @generate_barcode.current_order_position = 0
        @generate_barcode.total_orders = orders.length
        @generate_barcode.next_order_increment_id = orders.first[:increment_id] unless orders.first.nil?
        @generate_barcode.status = 'scheduled'

        @generate_barcode.save
        delayed_job = GeneratePackingSlipPdf.delay(:run_at => 1.seconds.from_now).generate_packing_slip_pdf(orders, Apartment::Tenant.current, @slip_data_hash, @page_height, @page_width, @orientation, @file_name, @size, @header, @generate_barcode.id)
        @generate_barcode.delayed_job_id = delayed_job.id
        @generate_barcode.save
        result['status'] = true
      end
    end

    def generate_order_barcode_slip(order)
      require 'wicked_pdf'
      GenerateBarcode.where('updated_at < ?', 24.hours.ago).delete_all
      @generate_barcode = GenerateBarcode.new
      @generate_barcode.user_id = @current_user.id
      @generate_barcode.current_order_position = 0
      @generate_barcode.total_orders = 1
      @generate_barcode.current_increment_id = order.increment_id
      @generate_barcode.next_order_increment_id = nil
      @generate_barcode.status = 'in_progress'

      @generate_barcode.save
      file_name_order = Digest::MD5.hexdigest(order.increment_id)
      reader_file_path = Rails.root.join('public', 'pdfs', "#{Apartment::Tenant.current}.#{file_name_order}.pdf")
      ActionView::Base.send(:define_method, :protect_against_forgery?) { false }
      av = ActionView::Base.new()
      av.view_paths = ActionController::Base.view_paths
      av.class_eval do
        include Rails.application.routes.url_helpers
        include ApplicationHelper
        include ProductsHelper
      end
      @order = order
      tenant_name = Apartment::Tenant.current
      file_name = tenant_name + Time.now.strftime('%d_%b_%Y_%I__%M_%p')
      pdf_path = Rails.root.join('public', 'pdfs', "#{file_name}_order_number.pdf")
      pdf_html = av.render :template => '@orders/generate_order_barcode_slip.html.erb', :layout => nil, :locals => {:@order => @order}
      doc_pdf = WickedPdf.new.pdf_from_string(
        pdf_html,
        :inline => true,
        :save_only => false,
        :page_height => '1in',
        :page_width => '3in',
        :margin => {:top => '0',
                    :bottom => '0',
                    :left => '0',
                    :right => '0'}
      )
      File.open(reader_file_path, 'wb') do |file|
        file << doc_pdf
      end
      base_file_name = File.basename(pdf_path)
      pdf_file = File.open(reader_file_path)
      GroovS3.create_pdf(tenant_name, base_file_name, pdf_file.read)
      pdf_file.close
      @generate_barcode.url = ENV['S3_BASE_URL']+'/'+tenant_name+'/pdf/'+base_file_name
      @generate_barcode.status = 'completed'
      @generate_barcode.save
    end
  end
end