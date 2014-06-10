module Groovepacker
	module PackingSlip
		class PdfMerger
		  def merge(pdf_paths, destination)
			  if pdf_paths.any?


			  	#join the path names with a space in between each consicutive paths
			  	joined_paths = pdf_paths.join(' ')
			  	puts joined_paths.inspect

			  	`pdftk #{pdf_paths.join(' ')} cat output #{destination.to_s}`

			    raise "Problem combining PDF files: #{pdf_paths.join(' ')}" unless $?.success?

			    destination
			  end
		  end
		end
	end
end