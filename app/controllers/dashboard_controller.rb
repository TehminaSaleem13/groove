class DashboardController < ApplicationController
  before_filter :groovepacker_authorize!
  # perform authorization too

  def exceptions
    results = []

    params[:exception_type] ||= 'most_recent'
    params[:user_id] = nil if params[:user_id] == '-1'
    exception_stats = Groovepacker::Dashboard::Stats::Exception.new(params[:user_id])
    case params[:exception_type]
    when 'most_recent'
      results = exception_stats.most_recent
    else
      results = exception_stats.by_frequency
    end

    render json: results
  end

end
