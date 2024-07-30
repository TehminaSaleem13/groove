class OrderTagsController < ApplicationController
  before_action :set_order_tag, only: [:update]

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

  def create_or_update
    @order_tag = OrderTag.find_or_initialize_by(id: params["order_id"][:id])
    @order_tag.assign_attributes(order_tag_params)
    
    if @order_tag.save
      render json: @order_tag, status: :ok
    else
      render json: @order_tag.errors, status: :unprocessable_entity
    end
  end

  def update
    if @order_tag.update(order_tag_params)
      render json: @order_tag
    else
      render json: @order_tag.errors, status: :unprocessable_entity
    end
  end

  private

  def set_order_tag
    @order_tag = OrderTag.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'OrderTag not found' }, status: :not_found
  end

  def order_tag_params
    params.require(:order_id).permit(:name, :color, :isVisible)
  end
end
