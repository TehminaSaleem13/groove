class PackingCamController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_order, only: :show
  before_action :load_data, only: :show

  def show
    result = { status: true }
    if @order
      result.merge!(setting: @scan_pack_setting, order: @order, packing_cams: @order.packing_cams, order_items: @order.order_items)
      result.merge!(order_activities: @order.order_activities) if @scan_pack_setting.scanning_log
    else
      result[:status] = false
    end
    render json: result
  end

  private

  def load_data
    @scan_pack_setting = ScanPackSetting.first
  end

  def set_order
    @order = Order.includes(:order_items, :order_activities, :packing_cams).find_by(email: params[:email], increment_id: params[:order_number])
  end
end
