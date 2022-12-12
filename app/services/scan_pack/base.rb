module ScanPack
  class Base
    include ScanPack::Utilities::OrderDetailsAndNextItem
    include ProductsHelper
    def set_scan_pack_action_instances(current_user, session, params)
      @current_user = current_user
      @params = params
      @session = session
      @result = {
        'status' => true, 'error_messages' => [], 'success_messages' => [],
        'notice_messages' => [], 'data' => {}
      }
    end

    def set_error_messages(error_message)
      @result['status'] &= false
      @result['error_messages'].push(error_message)
    end

    def request_api(params)
      require "net/http"
      Apartment::Tenant.switch! params[:tenant]
      order = Order.find(params[:scan_pack][:_json])
      store = order.store
      magento_credential = MagentoCredentials.where(store_id: store.id).first unless MagentoCredentials.where(store_id: store.id).empty?
      unless magento_credential.nil?
        begin
          data = { 'key' => 'Gr00_$p4ck3RPJ2004k1R4', 'order_id' => order.increment_id, 'tracking_id' => order.tracking_num }
          x = Net::HTTP.post_form(URI.parse('https://www.shopakira.com/groovepacker'), data)
        rescue Exception => e
          Rollbar.error(e, e.message, Apartment::Tenant.current)
        end
      end
    end

    def can_order_be_scanned
      # result = false
      # max_shipments = AccessRestriction.order("created_at").last.num_shipments
      # total_shipments = AccessRestriction.order("created_at").last.total_scanned_shipments
      # if total_shipments < max_shipments
      #  result = true
      # else
      #  result = false
      # end
      # result
      true
    end

    def do_remove_barcode_updated_before_24h_and_return_new_barcode_object(generate_barcode_hash)
      GenerateBarcode.where('updated_at < ?', 24.hours.ago).delete_all
      GenerateBarcode.create(generate_barcode_hash)
    end

    def generate_packing_slip(order)
      @result['status'] = false

      do_setup_page_properties

      @file_name = Apartment::Tenant.current + Time.current.strftime('%d_%b_%Y_%I__%M_%p')
      orders = []

      @single_order = Order.find(order.id)
      if @single_order.present?
        orders.push(id: @single_order.id, increment_id: @single_order.increment_id)
      end
      unless orders.empty?
        do_generate_barcode_with_delayed_job(orders)
      else
        @result['notice_messages'].push('No Orders Found')
      end
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
      @slip_data_hash = {}
      @slip_data_hash['data'] = {}
      @slip_data_hash['data']['packing_slip_file_paths'] = []

      if @orientation == 'landscape'
        @page_height = @page_height.to_f / 2
        @page_height = @page_height.to_s
      end
      @header = ''
    end

    def do_generate_barcode_with_delayed_job(orders)
      generate_barcode = do_remove_barcode_updated_before_24h_and_return_new_barcode_object(user_id: @current_user.id,
                                                                                            current_order_position: 0,
                                                                                            total_orders: orders.length,
                                                                                            next_order_increment_id: orders.first && orders.first[:increment_id],
                                                                                            status: 'scheduled')
      @boxes ||= Box.where(order_id: orders.first[:id]).map(&:id)
      delayed_job = GeneratePackingSlipPdf.delay(run_at: 1.seconds.from_now, queue: 'generate_packing_slip_pdf', priority: 95).generate_packing_slip_pdf(orders, Apartment::Tenant.current, @slip_data_hash, @page_height, @page_width, @orientation, @file_name, @size, @header, generate_barcode.id, @boxes)
      generate_barcode.delayed_job_id = delayed_job.id
      generate_barcode.save
      @result['status'] = true
    end
    #---------------- Bar Code slip Ends here ---------------

    ################## BARCODE SLIP ################
    #-----------------------------------------------
    def generate_order_barcode_slip(order)
      generate_barcode = do_remove_barcode_updated_before_24h_and_return_new_barcode_object(user_id: @current_user.id,
                                                                                            current_order_position: 0,
                                                                                            total_orders: 1,
                                                                                            current_increment_id: order.increment_id,
                                                                                            next_order_increment_id: nil,
                                                                                            status: 'in_progress')
      base_file_name = do_generate_pdf_file_for_barcode(order)
      generate_barcode.url = ENV['S3_BASE_URL'] + '/' + @tenant_name + '/pdf/' + base_file_name
      generate_barcode.dimensions = "1x3"
      generate_barcode.print_type = 'order_barcode'
      generate_barcode.status = 'completed'
      generate_barcode.save
    end

    def do_generate_pdf_file_for_barcode(order)
      require 'wicked_pdf'

      action_view = do_get_action_view_object_for_html_rendering
      reader_file_path = do_get_pdf_file_path(order)
      @tenant_name = Apartment::Tenant.current
      file_name = @tenant_name + Time.current.strftime('%d_%b_%Y_%I__%M_%p')
      pdf_path = Rails.root.join('public', 'pdfs', "#{file_name}_order_number_#{order.increment_id}.pdf")
      pdf_html = action_view.render template: 'orders/generate_order_barcode_slip.html.erb', layout: nil, locals: { :@order => order }
      doc_pdf = WickedPdf.new.pdf_from_string(
        pdf_html,
        inline: true,
        save_only: false,
        page_height: '1in',
        page_width: '3in',
        margin: { top: '0', bottom: '0', left: '0', right: '0' }
      )
      File.open(reader_file_path, 'wb') do |file|
        file << doc_pdf
      end
      base_file_name = File.basename(pdf_path).gsub('#', '')
      pdf_file = File.open(reader_file_path)
      GroovS3.create_pdf(@tenant_name, base_file_name, pdf_file.read)
      pdf_file.close
      base_file_name
    end

    def do_get_action_view_object_for_html_rendering
      ActionView::Base.send(:define_method, :protect_against_forgery?) { false }
      action_view = ActionView::Base.new
      action_view.view_paths = ActionController::Base.view_paths
      action_view.class_eval do
        include Rails.application.routes.url_helpers
        include ApplicationHelper
        include ProductsHelper
      end
      action_view
    end

    def do_get_pdf_file_path(order)
      if order.is_a?(String)
        file_name_order = Digest::MD5.hexdigest(order)
      elsif order.respond_to?('store_product_id')
        file_name_order = order.store_product_id != 'undefined' ? Digest::MD5.hexdigest(order.store_product_id) : Digest::MD5.hexdigest(order.increment_id)
      else
        file_name_order = Digest::MD5.hexdigest(order.increment_id)
      end
      Rails.root.join(
        'public', 'pdfs', "#{Apartment::Tenant.current}.#{file_name_order}.pdf"
      )
    end
    #----------- BARCODE SLIP ENDS --------------

    def bulk_barcodes_with_delay(items, username = nil, type = nil, last_batch = nil)
      require 'wicked_pdf'
      action_view = do_get_action_view_object_for_html_rendering
      generate_url = generate_barcodes_pdf_and_url(type, items, action_view)
      if type == 'order_items'
        g = GenerateBarcode.new(url: generate_url, status: 'completed', current_increment_id: 'bulk_barcode')
        g.user_id = User.where(username: username).first.id rescue nil
        g.save
      else
        GroovRealtime.emit('barcode_lable', { url: generate_url, last_batch: last_batch, username: username }, :tenant)
      end
    end

    def generate_barcodes_pdf_and_url(type, items, action_view)
      general_settings = GeneralSetting.last
      file_name = Apartment::Tenant.current + Time.current.strftime('%d_%b_%Y_%I_%S_%M_%p') + "_bulk_barcode_generation_#{type}"
      show_bin_locations = general_settings.try(:show_primary_bin_loc_in_barcodeslip)
      show_sku_in_barcodeslip = general_settings.try(:show_sku_in_barcodeslip)
      case type
      when 'order_items'
        pdf_template = 'products/bulk_barcode_generation.html.erb'

        template_locals = { :@order_items => items, :@show_bin_locations => show_bin_locations, :@show_sku_in_barcodeslip => show_sku_in_barcodeslip }
        height_per_page = '1in'
        reader_file_path = Rails.root.join('public', 'pdfs', "bulk_barcode_generation.pdf")
      when 'products'
        printing_setting = PrintingSetting.all.last
        if printing_setting.present?
          product_barcode_label_size = printing_setting.product_barcode_label_size
        else
          product_barcode_label_size = '3 x 1'
        end
        pdf_template = 'products/print_barcode_label.html.erb'
        template_locals = { :@products => items, :@show_bin_locations => show_bin_locations, :@show_sku_in_barcodeslip => show_sku_in_barcodeslip, :@product_barcode_label_size => product_barcode_label_size}
        height_per_page = '1in'
        reader_file_path = do_get_pdf_file_path(items.count.to_s)
      end

      if printing_setting.present?
        case
        when printing_setting.product_barcode_label_size == '2 x 1'
          pdf_html = action_view.render :template => pdf_template, :layout => nil, :locals => template_locals
          common(pdf_html, reader_file_path, height_per_page, '2in', {:top => '0', :bottom => '0', :left => '0', :right => '0'})
        when printing_setting.product_barcode_label_size == '1.5 x 1'
          pdf_html = action_view.render :template => pdf_template, :layout => nil, :locals => template_locals
          common(pdf_html, reader_file_path, height_per_page, '1.5in', {:top => '0', :bottom => '0', :left => '0', :right => '0'})
        else
          pdf_html = action_view.render :template => pdf_template, :layout => nil, :locals => template_locals
          common(pdf_html, reader_file_path, height_per_page, '3in', {:top => '0', :bottom => '0', :left => '0', :right => '0'})
        end
      else
        pdf_html = action_view.render :template => pdf_template, :layout => nil, :locals => template_locals
        common(pdf_html, reader_file_path, height_per_page, '3in', {:top => '0', :bottom => '0', :left => '0', :right => '0'})
      end

      pdf_path = Rails.root.join('public', 'pdfs', "#{file_name}.pdf")
      base_file_name = File.basename(pdf_path)
      pdf_file = File.open(reader_file_path)
      GroovS3.create_pdf(Apartment::Tenant.current, base_file_name, pdf_file.read)
      pdf_file.close
      generate_url = ENV['S3_BASE_URL'] + '/' + Apartment::Tenant.current + '/pdf/' + base_file_name
    end

    def print_label_with_delay(params)
      require 'wicked_pdf'
      Apartment::Tenant.switch! params[:tenant]
      @products = list_selected_products(params)
      action_view = do_get_action_view_object_for_html_rendering
      reader_file_path = do_get_pdf_file_path(@products.count.to_s)
      @tenant_name = Apartment::Tenant.current
      file_name = @tenant_name + Time.current.strftime('%d_%b_%Y_%I__%M_%p')
      pdf_path = Rails.root.join('public', 'pdfs', "#{file_name}.pdf")
      pdf_html = action_view.render template: 'products/print_receiving_label.html.erb', layout: nil, locals: { :@products => @products }
      common(pdf_html, reader_file_path, '6in', '4in', top: '1', bottom: '0', left: '2', right: '2')
      base_file_name = File.basename(pdf_path)
      pdf_file = File.open(reader_file_path)
      GroovS3.create_pdf(@tenant_name, base_file_name, pdf_file.read)
      pdf_file.close
      url = ENV['S3_BASE_URL'] + '/' + @tenant_name + '/pdf/' + base_file_name
      GroovRealtime.emit('print_lable', url, :tenant) if params['productArray'].count > 20 || params['select_all'] == true
      url
    end

    def common(pdf_html, reader_file_path, h, w, val)
      doc_pdf = WickedPdf.new.pdf_from_string(
        pdf_html,
        inline: true,
        save_only: false,
        orientation: 'Portrait',
        page_height: h,
        page_width: w,
        margin: val
      )
      File.open(reader_file_path, 'wb') do |file|
        file << doc_pdf
      end
    end

    def finding_products(tenant)
      Apartment::Tenant.switch! tenant
      products = Product.where('updated_at < ? ', Time.zone.now - 90.days).pluck(:id)

      products = Product.includes(:order_items).where(id: products, order_items: { product_id: nil }).map(&:id)

      kit_product = ProductKitSkus.all.map(&:option_product_id).uniq

      products -= kit_product

      # products = Product.includes(:order_items).where(id: products , order_items: {product_id: nil}).where(product_kit_skus: {product_id: nil}).pluck(:id)

      products = find_products(products, :product_skus)
      products = find_products(products, :product_barcodes)
      products = find_products(products, :product_cats)
      products = find_products(products, :product_images)
      products = find_products(products, :product_inventory_warehousess)
      Product.where(id: products).update_all(status: 'inactive')
    end

    def find_products(products, val)
      if val == :product_inventory_warehousess
        new_products = Product.where(id: products).joins(val).where('product_inventory_warehouses.updated_at > ?', Time.current - 90.days).pluck(:id)
      else
        new_products = Product.where(id: products).joins(val).where("#{val}.updated_at > ?", Time.current - 90.days).pluck(:id)
      end
      products -= new_products
      products
    end

    def check_for_hex
      if (@input.starts_with? '^#^') && (@input.split('^')[2].present? rescue nil)
        @input = @input.split('^')[2].to_i(16).to_s
        return 'store_order_id'
      end
      'increment_id'
    end
  end
end
