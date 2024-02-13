# frozen_string_literal: true

class External::BaseController < ApplicationController
  before_action :authorize_client!

  private

  def authorize_client!
    auth_header = request.headers['Authorization']
    authorized = auth_header.present? && auth_header.include?('Bearer') && ApiKey.exists?(token: auth_header.gsub('Bearer ', ''))

    render status: :unauthorized, json: 'Unauthorized Access' unless authorized
  end
end
