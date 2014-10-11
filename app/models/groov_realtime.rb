class GroovRealtime
  class << self
    def current_user_id=(user)
      Thread.current[:current_user_id] = user
    end

    def current_user_id
      Thread.current[:current_user_id]
    end

    def emit(type,data,scope = :user)
      allowed_scopes = [:global,:tenant,:user]
      unless allowed_scopes.include? scope
        scope = :user
      end
      channel = self.make_channel(scope)

      $redis.publish(channel,{type:type,data:data}.to_json)
    end

    def make_channel(scope)
      result = 'groovepacker'
      if [:tenant,:user].include?(scope)
        result+= ':'+Apartment::Tenant.current_tenant
      end
      if scope == :user
        result+= ':'+ self.current_user_id.to_s
      end
      result
    end
  end
end
