module Groovepacker
  module Dashboard
    module Stats
      class ShipmentStats

        def get_shipment_stats(name, avg_data=false)
          shipping_result = {}
          shipping_result['shipped_current'] = 0
          shipping_result['shipped_last'] = 0
          shipping_result['max_allowed'] = 0
          tenant = Tenant.where(name: name).first unless Tenant.where(name: name).empty?
          current_tenant = Apartment::Tenant.current_tenant
          unless tenant.nil?
            begin
              @access_restrictions = nil
              Apartment::Tenant.switch(tenant.name)
              # shipping_result['shipped_last6'] = []
              @access_restrictions = AccessRestriction.order("created_at")
              shipping_result['shipped_last6'] = []
              unless @access_restrictions.empty?
                data_length = @access_restrictions.length
                shipping_result['shipped_current'] = @access_restrictions[data_length - 1].total_scanned_shipments
                shipping_result['shipped_last'] = @access_restrictions[data_length - 2].total_scanned_shipments if data_length > 1
                shipping_result['max_allowed'] = @access_restrictions[data_length - 1].num_shipments
                shipping_result['max_users'] = @access_restrictions[data_length-1].num_users
                shipping_result['max_import_sources'] = @access_restrictions[data_length-1].num_import_sources
                shipping_result['allow_bc_inv_push'] = @access_restrictions[data_length-1].allow_bc_inv_push
                shipping_result['allow_mg_rest_inv_push'] = @access_restrictions[data_length-1].allow_mg_rest_inv_push
                shipping_result['allow_shopify_inv_push'] = @access_restrictions[data_length-1].allow_shopify_inv_push
                shipping_result['allow_teapplix_inv_push'] = @access_restrictions[data_length-1].allow_teapplix_inv_push
                shipping_result['allow_magento_soap_tracking_no_push'] = @access_restrictions[data_length-1].allow_magento_soap_tracking_no_push
                if avg_data
                  shipping_result['average_shipped'] = get_avg_shipped('current')
                  shipping_result['average_shipped_last'] = get_avg_shipped('last')
                end
                for i in 2..7 do
                  if data_length-i >= 0
                    shipped = {}
                    shipped['shipping_duration'] = (@access_restrictions[data_length-i].created_at - 1.month).strftime("%d %b") + " - " + @access_restrictions[data_length-i].created_at.strftime("%d %b")
                    shipped['shipped_count'] = @access_restrictions[data_length-i].total_scanned_shipments.to_s
                    shipping_result['shipped_last6'] << shipped
                  else
                    shipping_result['shipped_last6'] << {'shipping_duration' => '-', 'shipped_count' => '-'}
                  end
                end
              else
                shipping_result['shipped_current'] = 0
                shipping_result['shipped_last'] = 0
                shipping_result['max_allowed'] = 0
                shipping_result['max_users'] = 0
                shipping_result['max_import_sources'] = 0
                shipping_result['average_shipped'] = 0
                shipping_result['average_shipped_last'] = 0
                shipping_result['shipped_last6'] = [{'shipping_duration' => '-', 'shipped_count' => '-'}]
              end
            rescue
              shipping_result['shipped_current'] = 0
              shipping_result['shipped_last'] = 0
              shipping_result['max_allowed'] = 0
              shipping_result['max_users'] = 0
              shipping_result['max_import_sources'] = 0
              shipping_result['average_shipped'] = 0
              shipping_result['average_shipped_last'] = 0
              shipping_result['shipped_last6'] = [{'shipping_duration' => '-', 'shipped_count' => '-'}]
            end
          end
          Apartment::Tenant.switch(current_tenant)
          puts "shipping_result['shipped_last6']: " + shipping_result['shipped_last6'].inspect
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
      end
    end
  end
end
