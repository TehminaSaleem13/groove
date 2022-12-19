# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :groovepacker_authorize!
  include ActionView::Helpers::NumberHelper
  # perform authorization too

  def exceptions
    results = []

    params[:exception_type] ||= 'most_recent'
    params[:user_id] = nil if params[:user_id] == '-1'
    exception_stats = Groovepacker::Dashboard::Stats::Exception.new(params[:user_id])
    results = case params[:exception_type]
              when 'most_recent'
                exception_stats.most_recent
              else
                exception_stats.by_frequency
              end

    render json: results
  end

  def get_stat_stream_manually
    results = { 'status' => true, 'message' => 'Your request has been queued.' }
    tenant = Apartment::Tenant.current
    stat_stream_obj = SendStatStream.new
    stat_stream_obj.delay(run_at: 1.seconds.from_now, queue: 'update_stats', priority: 95).update_stats(tenant)
    render json: results
  end

  def process_missing_data
    results = { 'status' => true, 'message' => 'Your request has been queued.' }
    tenant = Apartment::Tenant.current
    stat_stream_obj = SendStatStream.new
    stat_stream_obj.update_missing_data(tenant)
    render json: results
  end

  def generate_stats
    results = { 'status' => true }
    tenant = Apartment::Tenant.current
    stat_stream_obj = SendStatStream.new
    # stat_stream_obj.generate_export(tenant, params)
    stat_stream_obj.delay(run_at: 1.seconds.from_now, queue: 'generate_export', priority: 95).generate_export(tenant, params)
    render json: results
  end

  def update_to_avg_datapoint
    results = { 'status' => true }
    # HTTParty.post("https://api.#{ENV["GROOV_ANALYTIC"]}/dashboard/update_item_scan_time?actual=#{params["val"]}&avg=#{params["avg"]}&tenant=#{Apartment::Tenant.current}stat")
    response = HTTParty.post("#{ENV['GROOV_ANALYTIC_URL']}/dashboard/update_item_scan_time",
                             body: { actual: params['val'], avg: params['avg'], username: params['username'] }.to_json,
                             headers: { 'Content-Type' => 'application/json', 'tenant' => Apartment::Tenant.current })
    render json: results
  end

  def daily_packed_percentage
    orders = Order.select('order_placed_time, scanned_on').where('order_placed_time >= ?', Time.current.beginning_of_day - 60.days).order('order_placed_time desc').group_by { |o| o.order_placed_time.to_date }
    results = []
    processing = ExportSetting.first.processing_time
    orders.values.each_with_index do |order, index|
      imported = order.count
      scanned = 0
      unscanned = 0
      order.each do |ord|
        ord.scanned_on.blank? ? unscanned += 1 : scanned += 1
      end
      scanned = number_with_precision((scanned * 100) / imported.to_f, precision: 2)
      day = (orders.keys[index] + processing).strftime('%A')
      date = (orders.keys[index] + processing).strftime('%m/%d/%Y')
      results << { day: day, date: date, scanned: scanned, imported: imported, unscanned: unscanned }
    end
    render json: results
  end

  def download_daily_packed_csv
    daily_pack = DailyPacked.new
    daily_pack.delay(run_at: 1.seconds.from_now, queue: 'download_daily_packed_csv', priority: 95).send_csv_daily_pack(params, Apartment::Tenant.current)
    render json: {}
  end
end
