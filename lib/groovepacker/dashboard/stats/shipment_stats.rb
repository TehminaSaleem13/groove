module Groovepacker
  module Dashboard
    module Stats
      class ShipmentStats
        include ApplicationHelper
        
        def get_shipment_stats(name, avg_data = false)
          shipping_result = default_result
          @tenant = Tenant.where(name: name).first
          current_tenant = Apartment::Tenant.current_tenant
          if @tenant
            return shipping_result unless switch_tenant(@tenant.name)
            Apartment::Tenant.switch(@tenant.name)
            @access_restrictions = AccessRestriction.order('created_at')
            @access_record_count = @access_restrictions.length
            unless @access_restrictions.empty?
              shipping_result['shipped_last6'] = []
              get_shipping_result(shipping_result)
              get_avg_data(shipping_result) if avg_data
              get_old_shipped_count(shipping_result)
            end
            Apartment::Tenant.switch(current_tenant)
          end

          shipping_result
        end

        def get_avg_shipped(month)
          days = get_days(month)
          shipments = get_total_shipped(month)
          return (shipments == 0 || days == 0) ? 0 : (shipments / days).to_i
        end

        def get_days(month)
          return 0 if @access_record_count == 0
          date_diff = 0
          last_created = @access_restrictions.last.created_at
          if month == 'current'
            date_diff = Time.now - last_created
          elsif @access_record_count > 1 && month == 'last'
            date_diff = last_created - @access_restrictions[-2].created_at
          end
          days = date_diff / 86400
          ((date_diff % 86400) > 0) ? days + 1 : days
        end

        def get_total_shipped(month)
          if month == 'current'
            return @access_restrictions.last.total_scanned_shipments
          elsif @access_record_count > 1 && month == 'last'
            return @access_restrictions[-2].total_scanned_shipments
          end
        end

        private

        def default_result
          {
            'shipped_current' => 0,
            'shipped_last' => 0,
            'max_allowed' => 0,
            'max_users' => 0,
            'max_import_sources' => 0,
            'average_shipped' => 0,
            'average_shipped_last' => 0,
            'shipped_last6' => [
              {
                'shipping_duration' => '-',
                'shipped_count' => '-'
              }
            ]
          }
        end

        def accepted_data
          {
            'shipped_current' => 'total_scanned_shipments',
            'shipped_last' => 'total_scanned_shipments',
            'max_allowed' => 'num_shipments',
            'max_users' => 'num_users',
            'max_import_sources' => 'num_import_sources',
            'allow_bc_inv_push' => 'allow_bc_inv_push',
            'allow_mg_rest_inv_push' => 'allow_mg_rest_inv_push',
            'allow_shopify_inv_push' => 'allow_shopify_inv_push',
            'allow_teapplix_inv_push' => 'allow_teapplix_inv_push',
            'allow_magento_soap_tracking_no_push' => 'allow_magento_soap_tracking_no_push'
          }
        end

        def get_shipping_result(shipping_result)
          latest_access_data = @access_restrictions.last

          accepted_data.keys.each do |key|
            if key == 'shipped_last'
              shipping_result[key] = @access_restrictions[-2][accepted_data[key]] if @access_record_count > 1
            else
              shipping_result[key] = latest_access_data[accepted_data[key]]
            end
          end
        end

        def get_old_shipped_count(shipping_result)
          (2..7).each do |i|
            if @access_record_count - i >= 0
              shipped = {}
              access_data = @access_restrictions[-i]
              next if access_data.created_at.nil?
              shipped['shipping_duration'] =
                (access_data.created_at - 1.month).strftime('%d %b') +
                ' - ' + access_data.created_at.strftime('%d %b')
              shipped['shipped_count'] = access_data.total_scanned_shipments.to_s
              shipping_result['shipped_last6'] << shipped
            else
              shipping_result['shipped_last6'] << { 'shipping_duration' => '-',
                                                    'shipped_count' => '-'
                                                  }
            end
          end
        end

        def get_avg_data(shipping_result)
          shipping_result['average_shipped'] = get_avg_shipped('current')
          shipping_result['average_shipped_last'] = get_avg_shipped('last')
        end
      end
    end
  end
end
