# frozen_string_literal: true

class External::BaseController < ApplicationController
  before_action :authorize_client!

  private

  def authorize_client!
    return render_unauthorized unless Tenant.find_by_name(Apartment::Tenant.current)&.enable_developer_tools

    auth_header = request.headers['Authorization']
    authorized = auth_header.present? && auth_header.include?('Bearer') && ApiKey.exists?(token: auth_header.gsub('Bearer ', ''))

    render_unauthorized unless authorized
  end

  def render_unauthorized
    render status: :unauthorized, json: 'Unauthorized Access'
  end
end
