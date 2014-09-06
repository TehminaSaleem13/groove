module ApplicationHelper
 def pdf_image_tag(image, options = {})
  options[:src] = File.expand_path(Rails.root) + '/public/images/' + image
  puts options.to_s
 	tag(:img, options)
 end	
 def generate_order_barcode(increment_id)
    order_barcode = Barby::Code128B.new(increment_id)
    outputter = Barby::PngOutputter.new(order_barcode)
    outputter.margin = 0
    outputter.xdim = 2
    blob = outputter.to_png #Raw PNG data
    File.open("#{Rails.root}/public/images/#{increment_id}.png", 
      'w') do |f|
      f.write blob
    end
    increment_id
  end
end
