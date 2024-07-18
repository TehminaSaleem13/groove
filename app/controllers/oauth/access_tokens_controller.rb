class Oauth::AccessTokensController < Doorkeeper::TokensController
  after_action :log_auth, only: [:create]

  def revoke
    $redis.hdel('groovehacks:session', params[:token])

    super
  end

  private

  def log_auth
    data = JSON.parse(response.body)
    if data['access_token'].present?
      resource_owner_id = Doorkeeper::AccessToken.find_by(token: data['access_token']).resource_owner_id
      create_log_for_resource(resource_owner_id) if resource_owner_id.present?
    end
	rescue => e
    Rails.logger.info(e.message)
  end

  def create_log_for_resource(resource_owner_id)
    user = User.find_by(id: resource_owner_id)
    logs = { user_id: user.id, user_name: user.username }
		request_platform = request.headers['HTTP_ORIGIN'] ? 'GPX' : 'GPS'
    Groovepacker::LogglyLogger.log(Apartment::Tenant.current, "#{request_platform}_user_session", logs) if user.present?
  end
end
