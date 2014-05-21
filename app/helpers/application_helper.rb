module ApplicationHelper
 def pdf_image_tag(image, options = {})
  options[:src] = File.expand_path(Rails.root) + '/public/images/' + image
  puts options.to_s
 	tag(:img, options)
 end	
end
