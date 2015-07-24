class PaymentsController < ApplicationController

  before_filter :groovepacker_authorize!, :get_current_tenant
  include PaymentsHelper

  def index
    card_list(@current_tenant) unless @current_tenant.nil?
    render json: @result
  end

  def create
    add_card(params[:payment],@current_tenant) unless @current_tenant.nil?
    render json: @result
  end

  def edit
    make_default_card(params[:id],@current_tenant) unless @current_tenant.nil?
    render json: @result
  end

  def delete_cards
    params[:id].each do |id|
      delete_a_card(id,@current_tenant) unless @current_tenant.nil?
    end
    render json: @result
  end

  def default_card
    get_default_card(@current_tenant) unless @current_tenant.nil?
    render json: @result
  end

  private

  def get_current_tenant
    @current_tenant = Apartment::Tenant.current_tenant
  end
end