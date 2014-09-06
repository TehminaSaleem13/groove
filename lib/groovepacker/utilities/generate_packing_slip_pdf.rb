class GeneratePackingSlipPdf
  def self.generate_packing_slip_pdf(orders, tenant_name, result, page_height, page_width, orientation, file_name, size)
    # AccessRestriction.create(num_users: 100, num_shipments: 100, num_import_sources: 100)
    # if GeneralSetting.get_packing_slip_size == '4 x 6'
    #   page_height = '6'
    #   page_width = '4'
    # else
    #   page_height = '11'
    #   page_width = '8.5'
    # end
    # size = GeneralSetting.get_packing_slip_size
    # orientation = GeneralSetting.get_packing_slip_orientation
    # result = Hash.new
    # result['data'] = Hash.new
    # result['data']['packing_slip_file_paths'] = []

    # if orientation == "landscape"
    #   page_height = @page_height.to_f/2
    #   page_height = @page_height.to_s
    # end
    # header = ""
    # footer = ""

    # file_name = Time.now.strftime("%d_%b_%Y_%I:%M_%p")
    Apartment::Tenant.switch(tenant_name)
    packing_slip_obj = 
          Groovepacker::PackingSlip::PdfMerger.new
    orders.each do |item|
      order = Order.find(item['id'])

      GeneratePackingSlipPdf.generate_pdf(order,page_height,page_width,orientation,file_name)

      reader = PDF::Reader.new(Rails.root.join('public', 'pdfs', "#{order.increment_id}.pdf"))
      page_count = reader.page_count
      
      if page_count > 1
        # delete the pdf and regenerate if the pdf page-count exceeds 1
        File.delete(Rails.root.join('public', 'pdfs', order.increment_id+".pdf"))
        header = "Multi-Slip Order # " + order.increment_id
        footer = "Multi-Slip Order # " + order.increment_id
        GeneratePackingSlipPdf.generate_pdf(order,page_height,page_width,orientation,file_name)
      end
      result['data']['packing_slip_file_paths'].push(Rails.root.join('public','pdfs', "#{order.increment_id}.pdf"))
    end
    result['data']['destination'] =  Rails.root.join('public','pdfs', "#{file_name}_packing_slip.pdf")
    result['data']['merged_packing_slip_url'] =  '/pdfs/'+ file_name + '_packing_slip.pdf'
    
    #merge the packing-slips
    packing_slip_obj.merge(result,orientation,size,file_name)
    
    # render json: result        
    # end  
  end
  def self.generate_pdf(order,page_height,page_width,orientation,file_name)
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
      :page_size => 'Letter'
      # :orientation => orientation,
      # :page_height => page_height+'in', 
      # :page_width => page_width+'in',
      # :save_only => true,
      # :no_background => false,
      # :margin => {:top => '5',                     
      #             :bottom => '10',
      #             :left => '2',
      #             :right => '2'},
      # :footer => {
      #   :content => av.render_to_string('orders/generate_packing_slip_header.pdf.erb')
      # },
      # :header => {
      #   :content => av.render_to_string('orders/generate_packing_slip_header.pdf.erb')
      # },
      # :save_to_file => Rails.root.join('public', 'pdfs', "#{order.increment_id}.pdf")
    )
    pdf_path = Rails.root.join('public', 'pdfs', "#{@order.increment_id}.pdf")
    File.open(pdf_path, 'wb') do |file|
      file << doc_pdf
    end
  end
end