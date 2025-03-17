class CartsController < ApplicationController
  before_action  :groovepacker_authorize!
  before_action :set_cart, only: [:show, :update, :destroy]
  before_action :prevent_action_if_cart_in_use, only: [:update, :destroy]

  def index
    @carts = Cart.includes(:cart_rows).all
    render json: @carts, include: :cart_rows
  end

  def show
    render json: @cart, include: :cart_rows
  end

  def create
    @cart = Cart.new
    save_cart
  end

  def update
    save_cart
  end

  def destroy
    @cart.destroy
    head :no_content
  end

  def print_tote_labels
    @cart = Cart.includes(:cart_rows).find_by(cart_id: params[:id])

    tote_labels = []
    @cart.cart_rows.each do |row|
      row.row_count.times do |index|
        tote_id = "#{row.row_name}-#{index + 1}"
        tote_barcode_value = "#{tote_id}-#{@cart.cart_id}"
        tote_labels << {
          tote_id: tote_id,
          tote_barcode: tote_barcode_value,
          tote_barcode_value: tote_barcode_value,
          cart_name: @cart.cart_name
        }
      end
    end
  
    render pdf: "tote_labels_#{@cart.id}",
       template: "carts/tote_labels",
       formats: [:html],
       :page_height => '6in', :page_width => '4in',
       locals: { tote_labels: tote_labels }
  end
  

  private

  def prevent_action_if_cart_in_use
    orders = Order.where("assigned_cart_tote_id LIKE ?", "%-%-#{@cart.cart_id}")
    if orders.any?
      render json: { error: "Cart is in use by orders" }, status: :unprocessable_entity
    end
  end

  def set_cart
    @cart = Cart.find(params[:id])
  end

  def save_cart
    ActiveRecord::Base.transaction do
      @cart.assign_attributes(cart_name: params[:cart_name], cart_id: params[:cart_id], number_of_totes: params[:number_of_totes])
  
      if @cart.save
        process_cart_rows if params[:cart_rows].present?
        render json: @cart, include: :cart_rows, status: (@cart.previous_changes.empty? ? :ok : :created)
      else
        render json: @cart.errors, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
  
  def process_cart_rows
    @cart.cart_rows.destroy_all if @cart.persisted?
    params[:cart_rows].each do |row|
      @cart.cart_rows.create!(row_name: row[:row_name], row_count: row[:row_count])
    end
  end
  
  def cart_params
    params.permit(:cart_name, :cart_id, :number_of_totes, cart_rows: [:row_name, :row_count])
  end
end

