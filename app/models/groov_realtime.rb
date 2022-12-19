# frozen_string_literal: true

class GroovRealtime
  class << self
    def current_user_id=(user)
      Thread.current[:current_user_id] = user
    end

    def current_user_id
      Thread.current[:current_user_id]
    end

    def emit(event, data, scope = :tenant)
      allowed_scopes = %i[global tenant user]
      selected_scope = scope
      selected_scope = :tenant unless allowed_scopes.include? scope
      emit_to_channel(selected_scope, { event: event, data: data }, current_user_id)
    end

    def user_emit(event, data, uid)
      emit_to_channel(:user, { event: event, data: data }, uid)
    end

    def emit_to_channel(scope, data, uid)
      channel = 'groovepacker'
      channel += ':' + Apartment::Tenant.current if %i[tenant user].include?(scope)
      channel += ':' + uid.to_s if scope == :user

      $redis.publish(channel, data.to_json) unless Rails.env.test?
    end
  end
end
