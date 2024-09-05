# frozen_string_literal: true

class OrderActivitiesController < ApplicationController
  before_action :groovepacker_authorize!

  def acknowledge
    result = {}
    result['status'] = true
    result['messages'] = []

    activity = OrderActivity.find(params[:id])
    unless activity.update(acknowledged: true)
      result['status'] = false
      result['messages'].push('There was an error while acknowledging activity.')
    end
    activity.order.set_order_status
    render json: result
  end
end
