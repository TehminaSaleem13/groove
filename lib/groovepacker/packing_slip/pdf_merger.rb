module Groovepacker
  module PackingSlip
    class PdfMerger
      def merge(result, file_name)
        packing_slip_file_paths = result['data']['packing_slip_file_paths']
        if packing_slip_file_paths.any?
          input = result['data']['destination']

          #join the path names with a space in between each consicutive paths and give as input
          `pdftk #{packing_slip_file_paths.join(' ')} cat output #{input.to_s}`

          raise "Problem combining PDF files" unless $?.success?

          rearrange_pdfs(result, file_name) if size == '8.5 x 11' && orientation == 'landscape'

          #delete the perviously generated merged pdf
          File.delete(input)
        end
      end

      def rearrange_pdfs(result, file_name)
        result['data']['destination'] = Rails.root.join('public', 'pdfs', "#{file_name}_packing_slip_landscape.pdf")
        result['data']['merged_packing_slip_url'] = '/pdfs/'+ file_name + '_packing_slip_landscape.pdf'

        #render the merged pdf into a separate pdf as two packing_slips per page
        `pdfjam --nup 2x1 #{input} --outfile #{result['data']['destination'].to_s} --papersize '{11in,8.5in}'`
      end
    end
  end
end
