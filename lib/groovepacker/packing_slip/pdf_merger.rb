module Groovepacker
	module PackingSlip
		class PdfMerger
		  def merge(pdf_paths, destination, orientation, size, file_name)
			  if pdf_paths.any?


			  	#join the path names with a space in between each consicutive paths and give as input


			  	`pdftk #{pdf_paths.join(' ')} cat output #{destination.to_s}`

			    raise "Problem combining PDF files: #{pdf_paths.join(' ')}" unless $?.success?

			    # if size == '8.5 x 11' && orientation == 'landscape'
			    # 	input = destination
			    # 	render :pdf => file_name, 
       #          :template => 'orders/generate_packing_slip.html.erb',
       #          :page_height => '8.5in', 
       #          :page_width => '11in',
       #          :save_only => true,
       #          :no_background => false,
       #          :margin => {:top => '5',                     
       #                      :bottom => '10',
       #                      :left => '2',
       #                      :right => '2'},
       #          :save_to_file => Rails.root.join('public','pdfs', "#{file_name}_packing_slip.pdf")
       #      destination = Rails.root.join('public','pdfs', "#{file_name}_packing_slip.pdf")
       #      `pdfjam --nup 2x1 #{input} --outfile #{destination.to_s}`

       # 			destination = Rails.root.join('public','pdfs', "#{@file_name}_packing_slip_landscape.pdf")
		     #    @result['data']['merged_packing_slip_url'] =  '/pdfs/'+ @file_name + '_packing_slip_landscape.pdf'
		     #    `pdfjam --nup 2x1 #{input} --outfile #{destination.to_s} --papersize '{11in,8.5in}'`
			    # end
			  end
		  end
		end
	end
end