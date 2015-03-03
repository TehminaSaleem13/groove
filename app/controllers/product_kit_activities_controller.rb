class ProductKitActivitiesController < ApplicationController
  before_filter :authenticate_user!

  def acknowledge
    result = Hash.new
    result['status'] = true
    result['messages'] = []
    
    activity = ProductKitActivity.find(params[:id])
    unless activity.update_attributes(acknowledged: true)
      result['status'] = false
      result['messages'].push('There was an error while acknowledging activity.')
    end

    render json: result
  end
end
