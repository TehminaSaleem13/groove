# frozen_string_literal: true

module ScanPack
  class MailOutOfStockService < ScanPack::Base
    def initialize(current_user, session, params)
      set_scan_pack_action_instances(current_user, session, params)
      @order = Order.where(id: @params[:id]).first
      @general_settings = GeneralSetting.first
      @inventory = Product.where(id: @params[:product_id]).first.product_inventory_warehousess.first
      @warehouse = Product.where(id: @params[:product_id]).first.try(:primary_warehouse)
      @product = @order.get_unscanned_items.find { |product| product['product_id'] == @params[:product_id].to_i }
    end

    def run
      send_report_mail
      @result
    end

    def send_report_mail
      email_present = @general_settings.email_address_for_report_out_of_stock.present?
      if email_present
        do_if_order_and_email_present
      else
        @result['status'] &= false
        msg = if email_present
                'There was an error sending the out-of-stock report. Please try again.'
              else
                'Email not found for stock report settings.'
        end
        @result['error_messages'].push(msg)
      end
    end

    def do_if_order_and_email_present
      @result['success_messages'].push('Out of stock Report send successfully')
        mail_settings = {
          'email' => @general_settings.email_address_for_report_out_of_stock,
          'sender' => "#{@current_user.name} (#{@current_user.username})",
          'tenant_name' => Apartment::Tenant.current,
          'order_number' => @order.increment_id,
          'order_id' => @order.id,
          'product_id' => @product['product_id'],
          'location' => @product['location'],
          'location2' => @product['location2'],
          'location3' => @product['location3'],
          'product_name' => @product['name'],
          'product_sku' => @product['sku'],
          'product_qty_on_hand' =>  @warehouse.quantity_on_hand,
          'location_qty' => @inventory['location_primary_qty'],
          'location2_qty' => @inventory['location_secondary_qty'],
          'location3_qty' => @inventory['location_tertiary_qty']
        }
        OutOfStockReportMailer.send_email(mail_settings).deliver
    end
  end
end
