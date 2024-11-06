class PriorityCardsController < ApplicationController
    before_action :groovepacker_authorize!
    before_action :set_priority_card, only: %i[show update edit destroy]

    # GET /priority_cards
    def index
        ensure_regular_card
        
        regular_cards = PriorityCard.where(priority_name: "regular")
        
        priority_cards = PriorityCard.where.not(priority_name: "regular").map do |priority_card|
            priority_card.order_tagged_count = if priority_card.is_user_card
                                                    fetch_tagged_orders(find_user_by_username(priority_card.assigned_tag)).count
                                                else
                                                    calculate_tagged_count(priority_card.assigned_tag)
                                                end

            priority_card.oldest_order = if priority_card.is_user_card
                                            calculate_oldest_order(fetch_tagged_orders(find_user_by_username(priority_card.assigned_tag)))
                                         else
                                            get_oldest_order(priority_card.assigned_tag)
                                         end
            priority_card
        end
        
        @priority_cards = regular_cards + priority_cards
        
        render json: @priority_cards
    end

    # GET /priority_cards/:id
    def show
        render json: @priority_card
    end

    # POST /priority_cards
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

    # PUT /priority_cards/:id
    def update
        begin
            @priority_card = PriorityCard.find(params[:id])
        
            @priority_card.order_tagged_count = calculate_tagged_count(@priority_card.assigned_tag)
            @priority_card.oldest_order = get_oldest_order(@priority_card.assigned_tag)
        
            if @priority_card.update(priority_card_params)
                render json: @priority_card, notice: 'Priority card was successfully updated.'
            else
                render json: { error: "Failed to update priority card", messages: @priority_card.errors.full_messages }, status: :unprocessable_entity
            end
        rescue ActiveRecord::RecordNotFound => e
            render json: { error: 'Priority card not found' }, status: :not_found
        rescue StandardError => e
            Rails.logger.error("Error updating priority card: #{e.message}")
            render json: { error: "An error occurred while updating the priority card #{e.message}" }, status: :internal_server_error
        end
    end

    def update_positions
        begin
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
              return render json: { error: "Failed to update priority card with ID #{priority_card.id}", messages: priority_card.errors.full_messages }, status: :unprocessable_entity
            end
          end
      
          render json: updated_priority_cards, notice: 'Priority cards were successfully updated.'
          
        rescue ActiveRecord::RecordNotFound => e
          render json: { error: 'One or more priority cards not found' }, status: :not_found
        rescue StandardError => e
          Rails.logger.error("Error updating priority cards: #{e.message}")
          render json: { error: "An error occurred while updating the priority cards: #{e.message}" }, status: :internal_server_error
        end
      end
      

    # DELETE /priority_cards/:id
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

    def calculate_tagged_count(assigned_tag_name)
        OrderTag.where(name: assigned_tag_name).joins(:orders).where(orders: { status: 'awaiting' }).where(Order::RECENT_ORDERS_CONDITION, 14.days.ago).count
    end

    def get_oldest_order(assigned_tag_name)
        oldest_order = Order.joins(:order_tags)
                      .where(order_tags: { name: assigned_tag_name }, status: 'awaiting')
                      .where(Order::RECENT_ORDERS_CONDITION, 14.days.ago)
                      .order('created_at ASC')
                      .first
                      
        oldest_order ? oldest_order.created_at : ""
    end

    def ensure_regular_card
        awaiting_orders_count = count_awaiting_orders

        regular_card = PriorityCard.find_or_create_by(priority_name: 'regular') do |card|
            card.order_tagged_count = awaiting_orders_count
        end
        regular_card.position = '0' if regular_card.position.blank?

        update_order_count_if_needed(regular_card, awaiting_orders_count)
        regular_card.save!
    end

    def count_awaiting_orders
        Order
        .where(status: 'awaiting')
        .where(Order::RECENT_ORDERS_CONDITION, 14.days.ago)
        .left_joins(:order_tags) # Includes orders without tags
        .where(
            'order_tags.name IS NULL OR order_tags.name NOT IN (?)',
            PriorityCard.select(:assigned_tag)
        )
        .distinct
        .count
    end

    def update_order_count_if_needed(card, current_count)
        card.update(order_tagged_count: current_count) if card.order_tagged_count != current_count
    end

    def set_priority_card
        @priority_card = PriorityCard.find(params[:id])
    end

    def priority_card_params
        params.require(:priority_card).permit(:priority_name, :tag_color, :is_card_disabled, :assigned_tag, :is_stand_by, :position, :oldest_order, :is_favourite)
    end

    def find_user_by_username(username)
        User.find_by(username: username)
    end
      
    def render_user_not_found
        render json: { error: 'User not found' }, status: :not_found
    end
      
    def fetch_tagged_orders(user)
        Order.joins(:packing_user)
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
