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

  def get_stat_stream_manually
    results = {"status"=> true, "message" => "Your request has been queued."}
    tenant = Apartment::Tenant.current
    stat_stream_obj = SendStatStream.new()
    stat_stream_obj.delay(:run_at => 1.seconds.from_now, :queue => 'update_stats').update_stats(tenant)
    render json: results
  end

  def generate_stats
    results = {"status"=> true}
    tenant = Apartment::Tenant.current
    stat_stream_obj = SendStatStream.new()
    # stat_stream_obj.generate_export(tenant, params)
    stat_stream_obj.delay(:run_at => 1.seconds.from_now, :queue => 'generate_export').generate_export(tenant, params)
    render json: results
  end

  def update_to_avg_datapoint
    results = {"status"=> true}
    #HTTParty.post("https://api.#{ENV["GROOV_ANALYTIC"]}/dashboard/update_item_scan_time?actual=#{params["val"]}&avg=#{params["avg"]}&tenant=#{Apartment::Tenant.current}stat")
    response = HTTParty.post("#{ENV["GROOV_ANALYTIC_URL"]}/dashboard/update_item_scan_time",
        body: {actual: params["val"], avg: params["avg"], username: params["username"]}.to_json,
        headers: { 'Content-Type' => 'application/json', 'tenant' => Apartment::Tenant.current })
    render json: results
  end

end
