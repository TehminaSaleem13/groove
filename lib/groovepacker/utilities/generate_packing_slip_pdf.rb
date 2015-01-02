class GeneratePackingSlipPdf
  def self.generate_packing_slip_pdf(orders, tenant_name, result, page_height, page_width, orientation, file_name, size, header,gen_barcode_id)
    begin
      Apartment::Tenant.switch(tenant_name)
      packing_slip_obj =
            Groovepacker::PackingSlip::PdfMerger.new
      generate_barcode = GenerateBarcode.find_by_id(gen_barcode_id)
      unless generate_barcode.nil?
        generate_barcode.status = 'in_progress'
        generate_barcode.current_order_position = 0
        generate_barcode.total_orders = orders.length
        generate_barcode.next_order_increment_id = orders.first[:increment_id] unless orders.first.nil?
        generate_barcode.save
        orders.each_with_index do |item,index|

          order = Order.find(item[:id])
          generate_barcode.reload
          if generate_barcode.cancel
            generate_barcode.status = 'cancelled'
            generate_barcode.save
            return true
          end
          generate_barcode.current_increment_id = order.increment_id
          generate_barcode.next_order_increment_id = orders[(index.to_i+1)][:increment_id] unless index == (orders.length - 1)
          generate_barcode.current_order_position = (generate_barcode.current_order_position.to_i + 1)
          generate_barcode.save
          reader_file_path = Rails.root.join('public', 'pdfs', "#{Apartment::Tenant.current_tenant}.#{order.increment_id}.pdf")

          GeneratePackingSlipPdf.generate_pdf(order,page_height,page_width,orientation,reader_file_path,header)
          reader = PDF::Reader.new(reader_file_path)
          page_count = reader.page_count

          if page_count > 1
            # delete the pdf and regenerate if the pdf page-count exceeds 1
            File.delete(reader_file_path)
            multi_header = 'Multi-Slip Order # ' + order.increment_id
            GeneratePackingSlipPdf.generate_pdf(order,page_height,page_width,orientation,reader_file_path, multi_header)
          end
          result['data']['packing_slip_file_paths'].push(reader_file_path)
        end
        result['data']['destination'] =  Rails.root.join('public','pdfs', "#{file_name}_packing_slip.pdf")
        result['data']['merged_packing_slip_url'] =  '/pdfs/'+ file_name + '_packing_slip.pdf'

        #merge the packing-slips
        packing_slip_obj.merge(result,orientation,size,file_name)
        generate_barcode.url = result['data']['merged_packing_slip_url']
        generate_barcode.status = 'completed'
        generate_barcode.save
      end
    rescue Exception=> e
      generate_barcode.status = 'failed'
      generate_barcode.save
    end
  end
  def self.generate_pdf(order,page_height,page_width,orientation,pdf_path, header)
    require 'wicked_pdf'
    ActionView::Base.send(:define_method, :protect_against_forgery?) { false }
    av = ActionView::Base.new()
    av.view_paths = ActionController::Base.view_paths
    av.class_eval do
      include Rails.application.routes.url_helpers
      include ApplicationHelper
    end
    @order = order
    pdf_html = av.render :template => "orders/generate_packing_slip.html.erb", :layout => nil, :locals => {:@order => @order}
    doc_pdf = WickedPdf.new.pdf_from_string(
      pdf_html,
      :orientation => orientation,
      :page_height => page_height+'in',
      :page_width => page_width+'in',
      :save_only => true,
      :no_background => false,
      :margin => {:top => '5',
                  :bottom => '10',
                  :left => '2',
                  :right => '2'},
      :footer => {
        :content => av.render(:template => 'orders/generate_packing_slip_header.pdf.erb', :locals => {:@header => header})
      },
      :header => {
        :content => av.render(:template => 'orders/generate_packing_slip_header.pdf.erb', :locals => {:@header => header})
      }
    )
    File.open(pdf_path, 'wb') do |file|
      file << doc_pdf
    end
  end
end
