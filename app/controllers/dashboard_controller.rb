class DashboardController < ApplicationController
  before_filter :authenticate_user!
  # perform authorization too

  def main_summary    
    results = {}
    #default duration to 30
    params[:duration] = params[:duration] || 30
    
    #packed items
    results[:packed_items_summary] = {}
    current_month_packed_items = 0
    previous_month_packed_items = 0

    #current month packed items
    if params[:duration].to_i == -1
      start_time = nil 
    else
      start_time = (DateTime.now - params[:duration].to_i.days).beginning_of_day 
    end
    end_time = DateTime.now.end_of_day
    current_month_packed_items = 
      get_overall_packed_item_stats(start_time, end_time)


    if params[:duration].to_i != -1    
      #previous month packed items
      start_time = (DateTime.now - (2*(params[:duration].to_i)).days).beginning_of_day 
      end_time = (DateTime.now - (params[:duration].to_i - 1).days).end_of_day
      previous_month_packed_items = 
        get_overall_packed_item_stats(start_time, end_time)

      results[:packed_items_summary] = {
        current_period: current_month_packed_items,
        previous_period: previous_month_packed_items,
        delta: current_month_packed_items - previous_month_packed_items
      }
    else
      results[:packed_items_summary] = {
        current_period: current_month_packed_items,
        previous_period: previous_month_packed_items,
        delta: '-'
      }
    end



    render json: results
  end

  def packing_stats
    results = []
    #default duration to 30
    params[:duration] = params[:duration] || 30
    @users = User.all

    pallete = Groovepacker::Dashboard::Color::Pallete.new(
      @users.count, "006699")

    @users.each_with_index do |user, index|
      stat = {}
      stat[:key] = user.username
      stat[:color] = "#" + pallete.get(index)
      stat[:values] = get_packing_stats(user, params[:duration].to_i)
      results.push(stat)
    end

    render json: results
  end

  def packed_item_stats
    results = []
    #default duration to 30
    params[:duration] = params[:duration] || 30
    @users = User.all

    pallete = Groovepacker::Dashboard::Color::Pallete.new(
      @users.count, "006699")
    
    if params[:duration] == -1
      start_time = nil
    else
      start_time = (DateTime.now - params[:duration].to_i.days).beginning_of_day 
    end
    end_time = DateTime.now.end_of_day

    @users.each_with_index do |user, index|
      stat = {}
      stat[:key] = user.username
      stat[:color] = "#" + pallete.get(index)
      stat[:values] = get_packed_item_stats(user, start_time, end_time)
      results.push(stat)
    end

    render json: results
  end

  private

  def get_packing_stats(user, duration)
    stats_result = []
    start_time = (DateTime.now - duration.days).beginning_of_day
    end_time = DateTime.now.end_of_day
    if duration == -1
      orders = Order.where('scanned_on < ?', end_time).where(packing_user_id: 13).order(
        scanned_on: :ASC).group('date(scanned_on)').count
    else
      orders = Order.where(scanned_on: start_time..end_time).where(
        packing_user_id: user.id).order(
        scanned_on: :ASC).group('date(scanned_on)').count
    end

    orders.each do |order|
      order[0] = order[0].to_time.to_i
      stats_result.push(order)
    end

    stats_result
  end

  def get_packed_item_stats(user, start_time, end_time)
    stats_result = []

    if start_time == nil
      orders = Order.where('scanned_on < ?', end_time).where(
        packing_user_id: user.id).order(
        scanned_on: :ASC).group('date(scanned_on)')
      scanned_dates = Order.where('scanned_on < ?', end_time).where(
        packing_user_id: user.id).order(
        scanned_on: :ASC).group('date(scanned_on)').pluck(:scanned_on)
    else
      orders = Order.where(scanned_on: start_time..end_time).where(
        packing_user_id: user.id).order(
        scanned_on: :ASC).group('date(scanned_on)')
      scanned_dates = Order.where(scanned_on: start_time..end_time).where(
        packing_user_id: user.id).order(
        scanned_on: :ASC).group('date(scanned_on)').pluck(:scanned_on)
    end

    scanned_dates.each_with_index do |scanned_date, index|
      scanned_orders = Order.where(scanned_on: scanned_date.beginning_of_day..scanned_date.end_of_day).where(packing_user_id: user.id)
      count = 0
      puts scanned_orders.inspect
      scanned_orders.each do |scanned_order|
        count = count + scanned_order.order_items.count
      end
      stats_result.push([scanned_date.to_time.to_i, count])
    end

    stats_result
  end

  def get_overall_packed_item_stats(start_time, end_time)
    if start_time.nil?
      orders = Order.where(status: 'scanned').where('scanned_on < ?', end_time)
    else
      orders = Order.where(status: 'scanned').where(scanned_on: start_time..end_time)
    end
    count = 0
    orders.each do |order|
      count = count + order.order_items.length
    end
    count
  end

end
