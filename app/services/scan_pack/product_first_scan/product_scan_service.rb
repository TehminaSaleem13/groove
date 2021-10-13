# frozen_string_literal: true

module ScanPack
  module ProductFirstScan
    class ProductScanService < Base
      include ScanPack::ProductFirstScan::ToteScanHelper

      def run
        begin
          case params[:type]
          when 'assigned_to_tote'
            run_assigned_to_tote
          when 'put_in_tote'
            run_put_in_tote
          when 'scan_tote_to_complete'
            run_scan_tote_to_complete
          end
        rescue StandardError => e
          @result[:status] = false
          @result[:error_messages] = e.to_s
        end
        @result
      end

            private

      def tote
        @tote ||= if params[:tote][:id].present?
                    Tote.find(params[:tote][:id])
                  else
                    tote_params = params[:tote].slice(:id, :name, :number, :order_id, :tote_set_id, :pending_order).permit!
                    Tote.create(tote_params)
                  end
      end

      def order_item
        @order_item ||= OrderItem.find(params[:order_item_id])
      end

      def order
        @order ||= order_item.order
      end

      def valid_tote
        tote.name.casecmp(params[:tote_barcode].downcase).zero?
      end

      def set_wrong_tote
        @result[:status] = false
        @result[:error_messages] = "Whoops! That’s the wrong #{tote_identifier}. Please scan the correct #{tote_identifier} and then add the item to it."
      end
    end
  end
end
