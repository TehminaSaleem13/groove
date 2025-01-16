class PriorityCardsController < ApplicationController
  before_action :groovepacker_authorize!
  before_action :set_priority_card, only: %i[show update edit destroy]
  before_action :empty_order_count, :get_priority_cards, :last_14_days_orders

  def index
    @priority_cards = recalculate_priority_cards_count

    render json: @priority_cards
  end

  def show
    render json: @priority_card
  end

  def create
    @priority_card = PriorityCard.new(priority_card_params)
    @priority_card.order_tagged_count = calculate_tagged_count(@priority_card.assigned_tag)
    @priority_card.oldest_order = get_oldest_order(@priority_card.assigned_tag)

    if @priority_card.save
      render json: @priority_card, status: :created
    else
      render json: @priority_card.errors, status: :unprocessable_entity
    end
  end

  def update
    @priority_card = PriorityCard.find(params[:id])

    if @priority_card.update(priority_card_params)
      @priority_cards = recalculate_priority_cards_count
      @priority_card = PriorityCard.find(params[:id])
      render json: @priority_card, notice: 'Priority card was successfully updated.'
    else
      render json: { error: 'Failed to update priority card', messages: @priority_card.errors.full_messages },
             status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: 'Priority card not found' }, status: :not_found
  rescue StandardError => e
    Rails.logger.error("Error updating priority card: #{e.message}")
    render json: { error: "An error occurred while updating the priority card #{e.message}" },
           status: :internal_server_error
  end

  def update_positions
    updates = params[:updates]

    if updates.blank? || !updates.is_a?(Array)
      return render json: { error: 'Invalid update data' }, status: :unprocessable_entity
    end

    updated_priority_cards = []

    updates.each do |update_data|
      priority_card = PriorityCard.find(update_data[:id])

      priority_card.position = update_data[:new_position]
      if priority_card.save
        updated_priority_cards << priority_card
      else
        return render json: { error: "Failed to update priority card with ID #{priority_card.id}", messages: priority_card.errors.full_messages },
                      status: :unprocessable_entity
      end
    end

    get_priority_cards

    @priority_cards = recalculate_priority_cards_count

    render json: @priority_cards, notice: 'Priority cards were successfully updated.'
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: 'One or more priority cards not found' }, status: :not_found
  rescue StandardError => e
    Rails.logger.error("Error updating priority cards: #{e.message}")
    render json: { error: "An error occurred while updating the priority cards: #{e.message}" },
           status: :internal_server_error
  end

  def destroy
    @priority_card.destroy
  end

  def create_with_user
    user = find_user_by_username(params[:username])
    return render_user_not_found unless user

    tagged_orders = fetch_tagged_orders(user)

    @priority_card = build_priority_card(tagged_orders)

    if @priority_card.save
      render_created_priority_card
    else
      render_unprocessable_entity
    end
  end

  private

  def calculate_regular_order
    regular_card = @regular_cards.first
    regular_count = @recent_orders.count - @counted_order_ids.count
    regular_card.order_tagged_count = regular_count
    regular_order_ids = @recent_orders.pluck(:id) - @counted_order_ids
    regular_card.oldest_order = oldest_regular_card_order(regular_order_ids)
    regular_card.save
  end

  def recalculate_priority_cards_count
    ensure_regular_card

    @regular_cards = PriorityCard.where(priority_name: 'regular')

    @priority_cards_with_count = calculate_priority_cards_order_count

    calculate_regular_order

    @priority_cards = @regular_cards + @priority_cards_with_count

    @priority_cards
  end

  def get_priority_cards
    @priority_cards = PriorityCard.where.not(priority_name: 'regular').order(:position)
  end

  def last_14_days_orders
    @recent_orders = Order.where(status: 'awaiting').where(
        Order::RECENT_ORDERS_CONDITION, 14.days.ago
    )
  end

  def empty_order_count
    @counted_order_ids = []
  end

  def calculate_priority_cards_order_count
    @priority_cards.map do |priority_card|
      if priority_card.is_user_card
        priority_card.order_tagged_count = fetch_tagged_orders(find_user_by_username(priority_card.assigned_tag)).count
        priority_card.oldest_order = calculate_oldest_order(fetch_tagged_orders(find_user_by_username(priority_card.assigned_tag)))
      elsif priority_card.is_card_disabled
        priority_card.order_tagged_count = 0
        priority_card.oldest_order = get_oldest_order(priority_card.assigned_tag)
      else
        priority_card.order_tagged_count = calculate_tagged_count(priority_card.assigned_tag)
        priority_card.oldest_order = get_oldest_order(priority_card.assigned_tag)
      end
    end

    @priority_cards
  end

  def calculate_tagged_count(assigned_tag_name)
    @counted_order_ids ||= []
    orders_with_tag = Order
    .where(status: 'awaiting')
    .joins(:order_tags)
    .where(order_tags: { name: assigned_tag_name })
    .where(Order::RECENT_ORDERS_CONDITION, 14.days.ago)
    .where.not(id: @counted_order_ids)
    .distinct
    order_count = orders_with_tag.count

    order_ids = orders_with_tag.pluck('orders.id')

    @counted_order_ids += order_ids

    order_count
  end

  def oldest_regular_card_order(order_ids)
    oldest_order = Order.where(id: order_ids).order(:order_placed_time).first
    oldest_order ? oldest_order.order_placed_time : ''
  end

  def get_oldest_order(assigned_tag_name)
    oldest_order = Order.joins(:order_tags)
                        .where(order_tags: { name: assigned_tag_name }, status: 'awaiting')
                        .where(Order::RECENT_ORDERS_CONDITION, 14.days.ago)
                        .order('order_placed_time ASC')
                        .first

    oldest_order ? oldest_order.order_placed_time : ''
  end

  def ensure_regular_card
    PriorityCard.find_or_create_by(priority_name: 'regular')
  end

  def set_priority_card
    @priority_card = PriorityCard.find(params[:id])
  end

  def priority_card_params
    params.require(:priority_card).permit(:priority_name, :tag_color, :is_card_disabled, :assigned_tag,
                                          :is_stand_by, :position, :oldest_order, :is_favourite)
  end

  def find_user_by_username(username)
    User.find_by(username:)
  end

  def render_user_not_found
    render json: { error: 'User not found' }, status: :not_found
  end

  def fetch_tagged_orders(user)
    Order.joins(:assigned_user)
         .where(users: { username: user.username })
         .where(Order::RECENT_ORDERS_CONDITION, 14.days.ago)
         .where(status: 'awaiting')
  end

  def build_priority_card(tagged_orders)
    PriorityCard.new(priority_card_params).tap do |card|
      card.order_tagged_count = calculate_order_tagged_count(tagged_orders)
      card.oldest_order = calculate_oldest_order(tagged_orders)
      card.is_user_card = true
    end
  end

  def calculate_order_tagged_count(tagged_orders)
    tagged_orders.count.to_s
  end

  def calculate_oldest_order(tagged_orders)
    tagged_orders.order(:order_placed_time).pick(:order_placed_time)
  end

  def render_created_priority_card
    render json: {
      priority_card: @priority_card,
      user_order_count: @priority_card.order_tagged_count
    }, status: :created
  end

  def render_unprocessable_entity
    render json: @priority_card.errors, status: :unprocessable_entity
  end
end
