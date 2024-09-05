# frozen_string_literal: true

class ProductKitActivitiesController < ApplicationController
  before_action :groovepacker_authorize!

  def acknowledge
    result = {}
    result['status'] = true
    result['messages'] = []

    activity = ProductKitActivity.find(params[:id])
    unless activity.update(acknowledged: true)
      result['status'] = false
      result['messages'].push('There was an error while acknowledging activity.')
    end

    render json: result
  end
end
