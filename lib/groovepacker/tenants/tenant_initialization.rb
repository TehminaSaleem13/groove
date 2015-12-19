module Groovepacker
  module Tenants
    class TenantInitialization
      def access_limits(plan)
        result = {}
        case plan
        when 'groove-solo', 'annual-groove-solo'
          result = build_access_hash(500, 1, 1)
        when 'groove-duo', 'annual-groove-duo'
          result = build_access_hash(2000, 2, 2)
        when 'groove-trio', 'annual-groove-trio'
          result = build_access_hash(6000, 3, 3)
        when 'groove-quintet', 'annual-groove-quintet'
          result = build_access_hash(12000, 5, 5)
        when 'groove-symphony', 'annual-groove-symphony'
          result = build_access_hash(50000, 12, 8)
        end
        result
      end

      def build_access_hash(shipments, users, stores)
        result = {}
        result[:access_restrictions_info] = {}
        result[:access_restrictions_info][:max_allowed] = shipments
        result[:access_restrictions_info][:max_users] = users
        result[:access_restrictions_info][:max_import_sources] = stores
        result
      end
    end
  end
end
