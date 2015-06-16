module ApplicationHelper

 def pdf_image_tag(image, options = {})
  options[:src] = File.expand_path(Rails.root) + '/public/images/' + image
  tag(:img, options)
 end  

 def generate_order_barcode(increment_id)
    order_barcode = Barby::Code128B.new(increment_id)
    outputter = Barby::PngOutputter.new(order_barcode)
    outputter.margin = 0
    outputter.xdim = 2
    blob = outputter.to_png #Raw PNG data
    image_name = Digest::MD5.hexdigest(increment_id)
    File.open("#{Rails.root}/public/images/#{image_name}.png", 
      'w') do |f|
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
end
