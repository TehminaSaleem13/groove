# frozen_string_literal: true

module ApplicationHelper
  def pdf_image_tag(image, options = {})
    options[:src] = File.expand_path(Rails.root) + '/public/images/' + image
    tag(:img, options)
  end

  def generate_order_barcode(increment_id)
    order_barcode = Barby::Code128.new(increment_id)
    outputter = Barby::PngOutputter.new(order_barcode)
    outputter.margin = 0
    outputter.xdim = 2
    blob = outputter.to_png # Raw PNG data
    image_name = Digest::MD5.hexdigest(increment_id)
    File.open("#{Rails.root}/public/images/#{image_name}.png",
              'wb') do |f|
      f.write blob
    end
    image_name
  end

  def non_hyphenated_string(string)
    string.nil? ? nil : string.tr('-', '')
  end

  def is_base_tenant(request)
    request.original_url =~ /admin./
  end

  def rename_file(file, imported_string = '-imported')
    new_file = ''
    substrings = file.split('.')
    substrings.each do |value|
      new_file += if value == substrings[-1]
                    ('.' + value)
                  elsif value == substrings[-2]
                    (value + imported_string)
                  else
                    value
                  end
    end
    new_file
  end

  def one_time_payment(attrs)
    if attrs[:shop_name].present? && attrs['shop_type'] == 'BigCommerce'
      ENV['BC_ONE_TIME_PAYMENT']
    elsif attrs[:shop_name].present? && attrs['shop_type'] == 'Shopify'
      ENV['SHOPIFY_ONE_TIME_PAYMENT']
    else
      ENV['ONE_TIME_PAYMENT']
    end
  end

  def render_pdf(file_name)
    render pdf: file_name,
           template: 'orders/generate_pick_list',
           orientation: 'portrait',
           page_height: '8in',
           save_only: true,
           page_width: '11.5in',
           margin: { top: '20', bottom: '20', left: '10', right: '10' },
           header: { spacing: 5, right: '[page] of [topage]' },
           footer: { spacing: 1 },
           handlers: [:erb],
           formats: [:html],
           save_to_file: Rails.root.join('public', 'pdfs', "#{file_name}.pdf")
  end

  def current_tenant
    Apartment::Tenant.current
  end

  def order_summary
    OrderImportSummary.where(status: 'in_progress').first
  end

  def order_summary_to_cancel
    OrderImportSummary.first
  end

  def settings_to_generate_packing_slip
    @page_height = '11'
    @page_width = '8.5'

    if GeneralSetting.get_packing_slip_size == '4 x 6'
      @page_height = '6'
      @page_width = '4'
    end
    if GeneralSetting.get_packing_slip_size == '4 x 4'
      @page_height = '4'
      @page_width = '4'
    end
    if GeneralSetting.get_packing_slip_size == '4 x 2'
      @page_height = '2'
      @page_width = '4'
    end

    @size = GeneralSetting.get_packing_slip_size
    @orientation = GeneralSetting.get_packing_slip_orientation
    @result['data'] = { 'packing_slip_file_paths' => [] }
    @page_height = (@page_height.to_f / 2).to_s if @orientation == 'landscape'
    @header = ''
    @file_name = current_tenant + Time.current.strftime('%d_%b_%Y_%I_%M_%S_%L_%p')
    @boxes = params[:box_ids]
    $redis.set("#{current_tenant}_packing_type", params[:packing_type]) unless params[:packing_type].blank?
  end

  def update_fail_status(result, message)
    result['status'] &= false
    result['error_messages'].push(message)
  end

  def result_hash
    {
      'status' => true,
      'error_messages' => [],
      'success_messages' => []
    }
  end

  def find_tenant(id)
    Tenant.find(id)
  end

  def switch_tenant(tenant)
    Apartment::Tenant.switch!(tenant)
    true
  rescue StandardError => e
    false
  end

  def socket_server
    return '' if ENV['SOCKET_ENDPOINT'].nil?

    request.protocol + 'splitsocket.' + ENV['SOCKET_ENDPOINT']
    # request.protocol + "#{Apartment::Tenant.current}.localpacker.com"
  end

  def order_item_scanned_qty(order_item, box)
    order_item.order_item_boxes.find_by_box_id(box.id).item_qty
  end
end
