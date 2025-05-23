# frozen_string_literal: true

module Groovepacker
  module PackingSlip
    class PdfMerger
      def merge(result, orientation, size, file_name)
        packing_slip_file_paths = result['data']['packing_slip_file_paths']
        return unless packing_slip_file_paths.any?

        input = result['data']['destination']

        # join the path names with a space in between each consicutive paths and give as input
        `pdftk #{packing_slip_file_paths.join(' ')} cat output #{input}`

        raise 'Problem combining PDF files' unless $CHILD_STATUS.success?

        rearrange_pdfs(result, file_name, input) if size == '8.5 x 11' && orientation == 'landscape'
      end

      def rearrange_pdfs(result, file_name, input)
        result['data']['destination'] = Rails.root.join('public', 'pdfs', "#{file_name}_packing_slip_landscape.pdf")
        result['data']['merged_packing_slip_url'] = '/pdfs/' + file_name + '_packing_slip_landscape.pdf'

        # render the merged pdf into a separate pdf as two packing_slips per page
        `pdfjam --nup 2x1 #{input} --outfile #{result['data']['destination']} --papersize '{11in,8.5in}'`
        # delete the perviously generated merged pdf
        File.delete(input)
      end

      def do_get_action_view_object_for_html_rendering
        ActionView::Base.send(:define_method, :protect_against_forgery?) { false }
        lookupcontext = ActionView::LookupContext.new([Rails.root.join('app/views')])
        action_view = ActionView::Base.with_empty_template_cache.new(
          lookupcontext, {}, nil
        )
        action_view.class_eval do
          include Rails.application.routes.url_helpers
          include ApplicationHelper
          include ProductsHelper
        end
        action_view
      end
    end
  end
end
