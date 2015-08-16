module Groovepacker
  module PackingSlip
    class PdfMerger
      def merge(result, orientation, size, file_name)
        if result['data']['packing_slip_file_paths'].any?


          #join the path names with a space in between each consicutive paths and give as input


          `pdftk #{result['data']['packing_slip_file_paths'].join(' ')} cat output #{result['data']['destination'].to_s}`

          raise "Problem combining PDF files: #{result['data']['packing_slip_file_paths'].join(' ')}" unless $?.success?

          if size == '8.5 x 11' && orientation == 'landscape'
            input = result['data']['destination']

            result['data']['destination'] = Rails.root.join('public', 'pdfs', "#{file_name}_packing_slip_landscape.pdf")
            result['data']['merged_packing_slip_url'] = '/pdfs/'+ file_name + '_packing_slip_landscape.pdf'

            #render the merged pdf into a separate pdf as two packing_slips per page
            `pdfjam --nup 2x1 #{input} --outfile #{result['data']['destination'].to_s} --papersize '{11in,8.5in}'`

            #delete the perviously generated merged pdf
            File.delete(input)
          end
        end
      end
    end
  end
end
