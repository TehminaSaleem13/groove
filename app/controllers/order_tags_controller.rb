class OrderTagsController < ApplicationController
  def index
    @order_tags = OrderTag.all.uniq { |tag| tag.name }
    render json: @order_tags
  end

  def search
    if params[:name].present?
      @order_tags = OrderTag.where('name LIKE ?', "%#{params[:name]}%")
      @order_tags = @order_tags.all.uniq { |tag| tag.name }
      render json: @order_tags
    else
      render json: { error: 'Name parameter is required' }, status: :bad_request
    end
  end
end