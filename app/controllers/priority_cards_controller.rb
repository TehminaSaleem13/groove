class PriorityCardsController < ApplicationController
    before_action :groovepacker_authorize!
    before_action :set_priority_card, only: %i[show update edit destroy]

    # GET /priority_cards
    def index
        ensure_regular_card

        @priority_cards = PriorityCard.all
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

    private

    def calculate_tagged_count(assigned_tag_name)
        OrderTag.where(name: assigned_tag_name).joins(:orders).where(orders: { status: 'awaiting' }).count
    end

    def get_oldest_order(assigned_tag_name)
        oldest_order = Order.joins(:order_tags)
                      .where(order_tags: { name: assigned_tag_name }, status: 'awaiting')
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
        Order.joins(:order_tags)
        .joins('LEFT JOIN priority_cards ON priority_cards.assigned_tag = order_tags.name')
        .where(status: 'awaiting')
        .where(priority_cards: { id: nil })
        .where('orders.created_at >= ?', 7.days.ago)
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
        params.require(:priority_card).permit(:priority_name, :tag_color, :is_card_disabled, :assigned_tag, :is_stand_by, :position, :oldest_order)
    end
end
