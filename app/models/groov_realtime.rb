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
      self.emit_to_channel(selected_scope,{event:event,data:data},self.current_user_id)
    end

    def user_emit(event,data,uid)
      self.emit_to_channel(:user,{event:event,data:data},uid)
    end

    def emit_to_channel(scope,data,uid)
      channel = 'groovepacker'
      if [:tenant,:user].include?(scope)
        channel+= ':'+Apartment::Tenant.current
      end
      if scope == :user
        channel+= ':'+ uid.to_s
      end

      $redis.publish(channel,data.to_json)
    end
  end
end
