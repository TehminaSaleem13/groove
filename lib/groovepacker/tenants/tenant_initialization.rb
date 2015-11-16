module Groovepacker
  module Tenants
    class TenantInitialization
      def access_limits(plan)
        result = {}
        result['access_restrictions_info'] = {}
        case plan
        when 'groove-solo'
          result['access_restrictions_info']['num_shipments'] = 500
          result['access_restrictions_info']['num_users'] = 1
          result['access_restrictions_info']['num_import_sources'] = 1
        when 'groove-duo'
          result['access_restrictions_info']['num_shipments'] = 2000
          result['access_restrictions_info']['num_users'] = 2
          result['access_restrictions_info']['num_import_sources'] = 2
        when 'groove-trio'
          result['access_restrictions_info']['num_shipments'] = 6000
          result['access_restrictions_info']['num_users'] = 3
          result['access_restrictions_info']['num_import_sources'] = 3
        when 'groove-quintet'
          result['access_restrictions_info']['num_shipments'] = 12000
          result['access_restrictions_info']['num_users'] = 5
          result['access_restrictions_info']['num_import_sources'] = 5
        when 'groove-symphony'
          result['access_restrictions_info']['num_shipments'] = 50000
          result['access_restrictions_info']['num_users'] = 12
          result['access_restrictions_info']['num_import_sources'] = 8
        when 'annual-groove-solo'
          result['access_restrictions_info']['num_shipments'] = 500
          result['access_restrictions_info']['num_users'] = 1
          result['access_restrictions_info']['num_import_sources'] = 1
        when 'annual-groove-duo'
          result['access_restrictions_info']['num_shipments'] = 2000
          result['access_restrictions_info']['num_users'] = 2
          result['access_restrictions_info']['num_import_sources'] = 2
        when 'annual-groove-trio'
          result['access_restrictions_info']['num_shipments'] = 6000
          result['access_restrictions_info']['num_users'] = 3
          result['access_restrictions_info']['num_import_sources'] = 3
        when 'annual-groove-quintet'
          result['access_restrictions_info']['num_shipments'] = 12000
          result['access_restrictions_info']['num_users'] = 5
          result['access_restrictions_info']['num_import_sources'] = 5
        when 'annual-groove-symphony'
          result['access_restrictions_info']['num_shipments'] = 50000
          result['access_restrictions_info']['num_users'] = 12
          result['access_restrictions_info']['num_import_sources'] = 8
        end
        result
      end
    end
  end
end
