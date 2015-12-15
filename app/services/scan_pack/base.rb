module ScanPack
  class Base
    include ScanPack::Utilities::OrderDetailsAndNextItem

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

    def do_remove_barcode_updated_before_24h_and_return_new_barcode_object(generate_barcode_hash)
      GenerateBarcode.where('updated_at < ?', 24.hours.ago).delete_all
      generate_barcode = GenerateBarcode.new(generate_barcode_hash)
      generate_barcode.save
      generate_barcode
    end

    def generate_packing_slip(order)
      result = Hash.new
      result['status'] = false

      do_setup_page_properties

      @file_name = Apartment::Tenant.current+Time.now.strftime('%d_%b_%Y_%I__%M_%p')
      orders = []

      @single_order = Order.find(order.id)
      if @single_order.present?
        orders.push({id: @single_order.id, increment_id: @single_order.increment_id})
      end
      do_generate_barcode_with_delayed_job(orders) unless orders.empty?
    end

    def do_setup_page_properties
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
    end

    def do_generate_barcode_with_delayed_job(orders)
      generate_barcode = do_remove_barcode_updated_before_24h_and_return_new_barcode_object({
        user_id: @current_user.id,
        current_order_position: 0,
        total_orders: orders.length,
        next_order_increment_id: orders.first && orders.first[:increment_id],
        status: 'scheduled'
        })
      delayed_job = GeneratePackingSlipPdf.delay(:run_at => 1.seconds.from_now).generate_packing_slip_pdf(orders, Apartment::Tenant.current, @slip_data_hash, @page_height, @page_width, @orientation, @file_name, @size, @header, generate_barcode.id)
      generate_barcode.delayed_job_id = delayed_job.id
      generate_barcode.save
      result['status'] = true
    end
    #---------------- Bar Code slip Ends here ---------------




    ################## BARCODE SLIP ################
    #-----------------------------------------------
    def generate_order_barcode_slip(order)
      generate_barcode = do_remove_barcode_updated_before_24h_and_return_new_barcode_object({
        user_id: @current_user.id,
        current_order_position: 0,
        total_orders: 1,
        current_increment_id: order.increment_id,
        next_order_increment_id: nil,
        status: 'in_progress'
        })
      base_file_name = do_generate_pdf_file_for_barcode(order)
      generate_barcode.url = ENV['S3_BASE_URL']+'/'+@tenant_name+'/pdf/'+base_file_name
      generate_barcode.status = 'completed'
      generate_barcode.save
    end

    def do_generate_pdf_file_for_barcode(order)
      require 'wicked_pdf'
      
      action_view = do_get_action_view_object_for_html_rendering
      reader_file_path = do_get_pdf_file_path(order)
      @tenant_name = Apartment::Tenant.current
      file_name = @tenant_name + Time.now.strftime('%d_%b_%Y_%I__%M_%p')
      pdf_path = Rails.root.join('public', 'pdfs', "#{file_name}_order_number.pdf")
      pdf_html = action_view.render :template => '@orders/generate_order_barcode_slip.html.erb', :layout => nil, :locals => {:@order => order}
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
      GroovS3.create_pdf(@tenant_name, base_file_name, pdf_file.read)
      pdf_file.close
      return base_file_name
    end

    def do_get_action_view_object_for_html_rendering
      ActionView::Base.send(:define_method, :protect_against_forgery?) { false }
      action_view = ActionView::Base.new()
      action_view.view_paths = ActionController::Base.view_paths
      action_view.class_eval do
        include Rails.application.routes.url_helpers
        include ApplicationHelper
        include ProductsHelper
      end
      action_view
    end

    def do_get_pdf_file_path(order)
      file_name_order = Digest::MD5.hexdigest(order.increment_id)
      Rails.root.join(
        'public', 'pdfs', "#{Apartment::Tenant.current}.#{file_name_order}.pdf"
        )
    end
    #----------- BARCODE SLIP ENDS --------------
  
  end
end