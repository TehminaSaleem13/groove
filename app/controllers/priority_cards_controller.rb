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

    # DELETE /priority_cards/:id
    def destroy
        @priority_card.destroy
    end

    private

    def calculate_tagged_count(assigned_tag_name)
        OrderTag.where(name: assigned_tag_name).joins(:orders).where(orders: { status: 'awaiting' }).count
    end

    def ensure_regular_card
        awaiting_orders_count = count_awaiting_orders

        regular_card = PriorityCard.find_or_create_by(priority_name: 'regular') do |card|
            card.order_tagged_count = awaiting_orders_count
        end

        update_order_count_if_needed(regular_card, awaiting_orders_count)
    end

    def count_awaiting_orders
        Order.where(status: 'awaiting').count
    end

    def update_order_count_if_needed(card, current_count)
        card.update(order_tagged_count: current_count) if card.order_tagged_count != current_count
    end

    def set_priority_card
        @priority_card = PriorityCard.find(params[:id])
    end

    def priority_card_params
        params.require(:priority_card).permit(:priority_name, :tag_color, :is_card_disabled, :assigned_tag, :is_stand_by)
    end
end
