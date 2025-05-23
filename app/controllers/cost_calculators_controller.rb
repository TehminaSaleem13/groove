# frozen_string_literal: true

class CostCalculatorsController < ApplicationController
  def index
    @params = {}
    @params = cost_calculation
    setting = GeneralSetting.last
    @calculator_url = setting.cost_calculator_url
    render json: @params
  end

  def email_calculations
    recipient_one = params[:recipient_one]
    recipient_two = params[:recipient_two]
    recipient_three = params[:recipient_three]
    if params['only_save'] == 'false'
      add_calculator_to_campaignmonitor if params['follow_up_email'] == 'true'
      CostCalculatorMailer.send_cost_calculation(params).deliver
    end
    setting = GeneralSetting.last
    setting.cost_calculator_url = '/cost_calculator?' + CGI.escape(params.permit!.except('controller', 'action',
                                                                                         'cost_calculator', 'recipient_one', 'recipient_two', 'recipient_three', 'recipient_four', 'follow_up_email').to_query)
    setting.save
    message = "Email Sent to #{recipient_one} #{recipient_two} #{recipient_three}"
    render json: { 'message' => message.gsub('undefined', ''), 'only_save' => params['only_save'] }
  end

  def add_calculator_to_campaignmonitor
    saving = params['monthly_saving'] || 0
    error = params['monthly_shipping'] || 0
    email = params['recipient_one']
    initialize_campaingmonitor.add_cost_calculator_lists(saving, error, email)
  end

  def initialize_campaingmonitor
    Groovepacker::CampaignMonitor::CampaignMonitor.new
  end

  private

  def cost_calculation
    { packer_count: params[:packer_count] || 3, order_count: params[:order_count] || 180, avg_error: params[:avg_error] || 2, regular_percentage: params[:regular_percentage] || 80, regular_comm: params[:regular_comm] || 0.45, escalated_percentage: params[:escalated_percentage] || 20, escalated_comm: params[:escalated_comm] || 3, avg_comm: params[:avg_comm] || 2, cost_ship_replacement: params[:cost_ship_replacement] || 3.25, expedited_count: params[:expedited_count] || 40, expedited_avg: params[:expedited_avg] || 25, international_count: params[:international_count] || 15, avg_order_profit: params[:avg_order_profit] || 30, reshipment: params[:reshipment] || 0.75, cost_labor_reshipment: params[:cost_labor_reshipment] || 0.20, cost_apology: params[:cost_apology] || 2, total_error_shipment: params[:total_error_shipment] || 35, product_abandonment_percentage: params[:product_abandonment_percentage] || 80, avg_product_abandonment: params[:avg_product_abandonment] || 6, return_shipping_percentage: params[:return_shipping_percentage] || 20, cost_return: params[:cost_return] || 0, return_shipping_cost: params[:return_shipping_cost] || 6, return_shipping_insurance: params[:return_shipping_insurance] || 1, cost_recieving_process: params[:cost_recieving_process] || 1, cost_confirm: params[:cost_confirm] || 0.25, misc_cost: params[:misc_cost] || 0, incorrect_current_order: params[:incorrect_current_order] || 15, avg_current_order: params[:avg_current_order] || 30, incorrect_lifetime_order: params[:incorrect_lifetime_order] || 40, lifetime_val: params[:lifetime_val] || 250, negative_shipment: params[:negative_shipment] || 150, inventory_shortage_order: params[:inventory_shortage_order] || 30, expedited_percentage: params[:expedited_percentage] || 2.5, international_percentage: params[:international_percentage] || 6.67, incorrect_current_order_per: params[:incorrect_current_order_per] || 6.67, incorrect_lifetime_order_per: params[:incorrect_lifetime_order_per] || 2.5, negative_shipment_per: params[:negative_shipment_per] || 1, inventory_shortage_order_per: params[:inventory_shortage_order_per] || 3.33, error_per_day: params[:error_per_day] || 10.80, total_replacement_costs: params[:total_replacement_costs] || 8.83, return_shipment_or_abandonment: params[:return_shipment_or_abandonment] || 2.24, intangible_cost: params[:intangible_cost] || 6, total_cost: params[:total_cost] || 17, error_cost_per_day: params[:error_cost_per_day] || 170, gp_cost: params[:gp_cost] || 150, total_expedited: params[:total_expedited] || 0.63, total_international: params[:total_international] || 2, cancel_order_shipment: params[:cancel_order_shipment] || 1.8, lifetime_order_val: params[:lifetime_order_val] || 5, negative_post_review: params[:negative_post_review] || 0, inventory_shortage: params[:inventory_shortage] || 0.9, monthly_shipping: params[:monthly_shipping] || 6904.5, monthly_saving: params[:monthly_saving] || 6754.50,
      email_text: params[:email_text], cost_header: params[:cost_header] }
  end
end
