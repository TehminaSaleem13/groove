# frozen_string_literal: true

class External::OrdersController < External::BaseController
  before_action :set_order, only: :retrieve

  def retrieve
    render json: External::OrderSerializer.new(@order).serializable_hash
  end

  private

  def set_order
    @order = Order.includes(order_items: :product).find_by(increment_id: params[:increment_id])
    return render json: { error: 'Order not found' }, status: :not_found unless @order
  end
end
