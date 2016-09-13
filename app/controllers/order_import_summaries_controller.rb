class OrderImportSummariesController < ApplicationController
  before_filter :groovepacker_authorize!
  
  def update_display_setting
    orderimportsummary = OrderImportSummary.last
    if orderimportsummary.present?
      orderimportsummary.display_summary = params[:flag]
      orderimportsummary.save
    end
    render json: {status: true}
  end

  def update_order_import_summary
    orderimportsummary = OrderImportSummary.first
    orderimportsummary.status = "not_started"
    orderimportsummary.save
    render json: {status: true}
  end

end

