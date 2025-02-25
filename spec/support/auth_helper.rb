# frozen_string_literal: true

module AuthHelper
  def setup_authentication
    @user ||= FactoryBot.create(:user)
    @token = FactoryBot.create(:access_token, resource_owner_id: @user.id)
    @doorkeeper_token = instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id)

    allow(controller).to receive(:doorkeeper_token) { @doorkeeper_token }
    allow(controller).to receive(:current_user) { @user }

    header = { 'Authorization' => "Bearer #{@token.token}" }
    @request.headers.merge! header
    User.current = @user
  end

  def setup_authentication_with_user(user)
    @token = FactoryBot.create(:access_token, resource_owner_id: user.id)
    @doorkeeper_token = instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: user.id)

    allow(controller).to receive(:doorkeeper_token) { @doorkeeper_token }
    allow(controller).to receive(:current_user) { user }

    header = { 'Authorization' => "Bearer #{@token.token}" }
    @request.headers.merge! header
    User.current = user
  end
end