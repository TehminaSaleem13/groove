class PaymentsController < ApplicationController  
  def get_card_list
    current_tenant = Apartment::Tenant.current_tenant
    subscription = Subscription.new
    @cards = subscription.card_list(current_tenant)
    respond_to do |format|
      format.html
      format.json {render json: @cards}
    end
  end

  def add_new_card
    current_tenant = Apartment::Tenant.current_tenant
    subscription = Subscription.new

    subscription.add_card(params,current_tenant)
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
  end
end