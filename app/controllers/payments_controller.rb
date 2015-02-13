class PaymentsController < ApplicationController  
  def card_details
    current_tenant = Apartment::Tenant.current_tenant
    subscription = Subscription.new
    @cards = subscription.card_list(current_tenant)
    puts @cards.inspect
    render json: @cards
    # respond_to do |format|
    #   puts "......................."
    #   format.html
    #   format.json {render json: @cards}
    # end
  end

  def create
    puts params.inspect
    puts params[:payment]
    current_tenant = Apartment::Tenant.current_tenant
    subscription = Subscription.new

    subscription.add_card(params[:payment],current_tenant)
  end

  def make_default
    current_tenant = Apartment::Tenant.current_tenant
    subscription = Subscription.new
    subscription.make_default_Card(params[:id],current_tenant)
  end

  def delete_card
    current_tenant = Apartment::Tenant.current_tenant
    subscription = Subscription.new
    subscription.delete_a_card(params[:id],current_tenant)
    render status: 200
  end

  def default_card
    puts "in default_card"
    current_tenant = Apartment::Tenant.current_tenant
    subscription = Subscription.new
    @card = subscription.get_default_card(current_tenant)
    render json: @card
  end
end