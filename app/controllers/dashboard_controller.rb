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

  def daily_packed_percentage
    orders = Order.select("created_at, scanned_on").where("created_at > ?", Time.now() - 30.days).group_by{ |o| o.created_at.to_date }    
    results = []
    orders.values.each_with_index do |order, index|
      imported = order.count
      scanned = 0
      unscanned = 0
      order.each do |ord|
        ord.scanned_on.blank? ? unscanned = unscanned + 1 : scanned = scanned + 1  
      end
      day = orders.keys[index].strftime("%A")
      date = orders.keys[index].strftime("%m/%d/%Y")
      results << { day: day, date: date, scanned: (scanned*100)/imported, imported: imported, unscanned: unscanned }
    end
    render json: results
  end
end
