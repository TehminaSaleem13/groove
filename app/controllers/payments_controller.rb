class PaymentsController < ApplicationController

  before_filter :get_current_tenant
  include PaymentsHelper

  def card_details
    @cards = card_list(@current_tenant) unless @current_tenant.nil?
    render json: @cards
  end

  def create
    add_card(params[:payment],@current_tenant) unless @current_tenant.nil?
    render json: @result
  end

  def edit
    make_default_card(params[:id],@current_tenant) unless @current_tenant.nil?
    render nothing: true
  end

  def destroy
    delete_a_card(params[:id],@current_tenant) unless @current_tenant.nil?
    render nothing: true
  end

  def default_card
    @card = get_default_card(@current_tenant) unless @current_tenant.nil?
    render json: @card
  end

  private

  def get_current_tenant
    @current_tenant = Apartment::Tenant.current_tenant
  end
end