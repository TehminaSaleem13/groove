# frozen_string_literal: true

class Internal::HealthCheckController < ApplicationController
  def index
    User.first
    render plain: 'OK'
  end
end
