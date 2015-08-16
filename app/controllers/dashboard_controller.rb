class DashboardController < ApplicationController
  before_filter :groovepacker_authorize!
  # perform authorization too

  def main_summary
    results = {}
    #default duration to 30
    params[:duration] = params[:duration] || 30

    #packed items
    results[:packed_items_summary] = {}

    packed_item_stats =
      Groovepacker::Dashboard::Stats::PackedItem.new(params[:duration].to_i)
    results[:packed_items_summary] = packed_item_stats.summary


    #packing speed
    results[:packing_speed_summary] = {}

    packing_speed_stats =
      Groovepacker::Dashboard::Stats::PackingSpeed.new(params[:duration].to_i)
    results[:packing_speed_summary] = packing_speed_stats.summary

    #packing accuracy
    results[:packing_accuracy_summary] = {}

    packing_accuracy_stats =
      Groovepacker::Dashboard::Stats::PackingAccuracy.new(params[:duration].to_i)
    results[:packing_accuracy_summary] = packing_accuracy_stats.summary

    render json: results
  end

  def packing_stats
    results = []
    #default duration to 30
    params[:duration] = params[:duration] || 30

    packed_accuracy_stats =
      Groovepacker::Dashboard::Stats::PackingAccuracy.new(params[:duration].to_i)

    results = packed_accuracy_stats.detail

    render json: results
  end

  def packing_speed
    results = []

    #default duration to 30
    params[:duration] = params[:duration] || 30

    packing_speed_stats =
      Groovepacker::Dashboard::Stats::PackingSpeed.new(params[:duration].to_i)

    results = packing_speed_stats.detail

    render json: results
  end

  def packed_item_stats
    results = []

    #default duration to 30
    params[:duration] = params[:duration] || 30

    packed_item_stats =
      Groovepacker::Dashboard::Stats::PackedItem.new(params[:duration].to_i)

    results = packed_item_stats.detail

    render json: results
  end

  def exceptions
    results = []

    params[:exception_type] = params[:exception_type] || 'most_recent'

    params[:user_id] = nil if params[:user_id] == '-1'

    exception_stats = Groovepacker::Dashboard::Stats::Exception.new(params[:user_id])

    if params[:exception_type] == 'most_recent'
      results = exception_stats.most_recent
    elsif params[:exception_type] == 'by_frequency'
      results = exception_stats.by_frequency
    end

    render json: results
  end

  def leader_board
    results = []

    results = Groovepacker::Dashboard::Stats::LeaderBoardStats.new.list

    render json: results
  end

end
