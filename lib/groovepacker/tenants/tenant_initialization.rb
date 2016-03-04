module Groovepacker
  module Tenants
    class TenantInitialization
      def access_limits(plan)
        build_access_hash(plan_hash[plan])
      end

      def plan_hash
        {
          'groove-duo-60' => {'shipments' => 2200, 'users' => 2, 'stores' => 2},
          'groove-trio-90' => {'shipments' => 4500, 'users' => 3, 'stores' => 3},
          'groove-quintet-120' => {'shipments' =>6700, 'users' => 4, 'stores' => 4},
          'groove-quartet-150' => {'shipments' =>9000, 'users' => 5, 'stores' => 5},
          'groove-bigband-210' => {'shipments' =>14000, 'users' => 7, 'stores' => 7},
          'groove-symphony-300' => {'shipments' => 20000, 'users' => 10, 'stores' => 20},
          'an-groove-duo' => {'shipments' => 2200, 'users' => 2, 'stores' => 2},
          'an-groove-trio' => {'shipments' => 4500, 'users' => 3, 'stores' => 3},
          'an-groove-quintet' => {'shipments' => 6700, 'users' => 4, 'stores' => 4},
          'an-groove-quartet' => {'shipments' => 9000, 'users' => 5, 'stores' => 5},
          'an-groove-bigband' => {'shipments' => 14000, 'users' => 7, 'stores' => 7},
          'an-groove-symphony' => {'shipments' => 20000, 'users' => 10, 'stores' => 20},
          'groove-solo' => {'shipments' => 500, 'users' => 1, 'stores' => 1},
          'groove-duo' => {'shipments' => 2000, 'users' => 2, 'stores' => 2},
          'groove-trio' => {'shipments' => 6000, 'users' => 3, 'stores' => 3},
          'groove-quintet' => {'shipments' => 12000, 'users' => 5, 'stores' => 5},
          'groove-symphony' => {'shipments' => 50000, 'users' => 12, 'stores' => 8},
          'annual-groove-solo' => {'shipments' => 500, 'users' => 1, 'stores' => 1},
          'annual-groove-duo' => {'shipments' => 2000, 'users' => 2, 'stores' => 2},
          'annual-groove-trio' => {'shipments' => 6000, 'users' => 3, 'stores' => 3},
          'annual-groove-quintet' => {'shipments' => 12000, 'users' => 5, 'stores' => 5},
          'annual-groove-symphony' => {'shipments' => 50000, 'users' => 12, 'stores' => 8}
        }
      end

      def build_access_hash(params)
        result = {}
        result[:access_restrictions_info] = {}
        result[:access_restrictions_info][:max_allowed] = params['shipments']
        result[:access_restrictions_info][:max_users] = params['users']
        result[:access_restrictions_info][:max_import_sources] = params['stores']
        result
      end
    end
  end
end
