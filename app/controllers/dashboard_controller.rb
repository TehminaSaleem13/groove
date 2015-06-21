class DashboardController < ApplicationController
  before_filter :authenticate_user!
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

  def packed_item_stats
    results = []

    #default duration to 30
    params[:duration] = params[:duration] || 30

    packed_item_stats = 
      Groovepacker::Dashboard::Stats::PackedItem.new(params[:duration].to_i)

    results = packed_item_stats.detail

    render json: results
  end

end
