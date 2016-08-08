module Groovepacker
  module Dashboard
    module Stats
      class AnalyticUserInfo
        def users_details(tenant, user_change_hash)
          users_info = []
          begin
            Apartment::Tenant.switch(tenant)
            @users = User.all
            unless @users.empty?
              @users.each do |user|
                result = build_result
                user_id = user.id
                result[:packing_user_id] = user_id
                result[:user_name] = user.username
                result[:active] = user.active
                result[:is_deleted] = user.is_deleted
                if user_change_hash
                  result[:previous_user_name] = user_change_hash[user_id.to_s]
                end
                users_info.push(result)
              end
            end
          rescue Exception => e
            puts e.message
          end
          users_info
        end

        def build_result
          {
            packing_user_id: 0,
            user_name: '',
            active: false,
            is_deleted: false,
            email: 'k4GPk' + Random.rand(10000000..99999999).to_s + '@gp4k.com',
            password: 'A4hKL30QMnlp'
          }
        end
      end
    end
  end
end
