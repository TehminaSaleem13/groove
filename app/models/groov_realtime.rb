class GroovRealtime
  class << self
    def current_user_id=(user)
      Thread.current[:current_user_id] = user
    end

    def current_user_id
      Thread.current[:current_user_id]
    end

    def emit(event,data,scope = :tenant)
      allowed_scopes = [:global,:tenant,:user]
      selected_scope = scope
      unless allowed_scopes.include? scope
        selected_scope = :tenant
      end
      channel = self.make_channel(selected_scope)

      $redis.publish(channel,{event:event,data:data}.to_json)
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
