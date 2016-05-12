module Groovepacker
  module Dashboard
    module Stats
      class ShipmentStats

        def get_shipment_stats(name, avg_data=false)
          shipping_result = {}
          @tenant = Tenant.where(name: name).first
          current_tenant = Apartment::Tenant.current_tenant
          if @tenant
            begin
              Apartment::Tenant.switch(@tenant.name)
              @access_restrictions = AccessRestriction.order("created_at")
              shipping_result['shipped_last6'] = []
              unless @access_restrictions.empty?
                get_shipping_result(shipping_result)
                # data_length = @access_restrictions.length
                # latest_access_data = @access_restrictions[data_length - 1]

                # accepted_data.keys.each do |key|
                #   if key == 'shipped_last'
                #     shipping_result[key] = @access_restrictions[data_length - 2].accepted_data[key]
                #   else
                #     shipping_result[key] = latest_access_data.accepted_data[key]
                #   end
                # end
                # shipping_result['shipped_current'] = latest_access_data.total_scanned_shipments
                # shipping_result['shipped_last'] = @access_restrictions[data_length - 2].total_scanned_shipments if data_length > 1
                # shipping_result['max_allowed'] = latest_access_data.num_shipments
                # shipping_result['max_users'] = latest_access_data.num_users
                # shipping_result['max_import_sources'] = latest_access_data.num_import_sources
                # shipping_result['allow_bc_inv_push'] = latest_access_data.allow_bc_inv_push
                # shipping_result['allow_mg_rest_inv_push'] = latest_access_data.allow_mg_rest_inv_push
                # shipping_result['allow_shopify_inv_push'] = latest_access_data.allow_shopify_inv_push
                # shipping_result['allow_teapplix_inv_push'] = latest_access_data.allow_teapplix_inv_push
                if avg_data
                  shipping_result['average_shipped'] = get_avg_shipped('current')
                  shipping_result['average_shipped_last'] = get_avg_shipped('last')
                end
                get_old_shipped_count(shipping_result)
                # for i in 2..7 do
                #   if data_length-i >= 0
                #     shipped = {}
                #     access_data = @access_restrictions[data_length-i]
                #     shipped['shipping_duration'] = (access_data.created_at - 1.month).strftime("%d %b") + " - " + access_data.created_at.strftime("%d %b")
                #     shipped['shipped_count'] = access_data.total_scanned_shipments.to_s
                #     shipping_result['shipped_last6'] << shipped
                #   else
                #     shipping_result['shipped_last6'] << {'shipping_duration' => '-', 'shipped_count' => '-'}
                #   end
                # end
              else
                raise
              end
            rescue
              shipping_result = default_result
            end
          end
          Apartment::Tenant.switch(current_tenant)
          shipping_result
        end

        def get_avg_shipped(month)
          days = get_days(month)
          shipments = get_total_shipped(month)
          return (shipments == 0 || days == 0) ? 0 : shipments.to_i/days
        end

        def get_days(month)
          date_diff = 0
          if month == "current"
            date_diff = Time.now - @access_restrictions.last.created_at
          elsif @access_restrictions.length > 1 && month == "last"
            date_diff = @access_restrictions.last.created_at - @access_restrictions[@access_restrictions.length - 2].created_at
          end
          return ((date_diff % 86400) > 0) ? (date_diff.to_i/86400)+1 : (date_diff.to_i/86400)
        end

        def get_total_shipped(month)
          if month == "current"
            return @access_restrictions.last.total_scanned_shipments
          elsif @access_restrictions.length > 1 && month == "last"
            return @access_restrictions[@access_restrictions.length - 2].total_scanned_shipments
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
            'allow_teapplix_inv_push' => 'allow_teapplix_inv_push'
          }
        end

        def get_shipping_result(shipping_result)
          data_length = @access_restrictions.length
          latest_access_data = @access_restrictions[data_length - 1]

          accepted_data.keys.each do |key|
            if key == 'shipped_last'
              shipping_result[key] = @access_restrictions[data_length - 2].accepted_data[key]
            else
              shipping_result[key] = latest_access_data.accepted_data[key]
            end
          end
        end

        def get_old_shipped_count(shipping_result)
          data_length = @access_restrictions.length
          (2..7).each do |i|
            if data_length - i >= 0
              shipped = {}
              access_data = @access_restrictions[data_length - i]
              shipped['shipping_duration'] =
                (access_data.created_at - 1.month).strftime("%d %b") +
                " - " + access_data.created_at.strftime("%d %b")
              shipped['shipped_count'] = access_data.total_scanned_shipments.to_s
              shipping_result['shipped_last6'] << shipped
            else
              shipping_result['shipped_last6'] << { 'shipping_duration' => '-',
                                                    'shipped_count' => '-'
                                                  }
            end
          end
        end
      end
    end
  end
end
