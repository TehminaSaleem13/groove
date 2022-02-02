# frozen_string_literal: true

module InventoryReport
  class SkuPerDay
    attr_accessor :products, :flag

    def initialize(product_inv_setting, products, flag)
      @product_inv_setting = product_inv_setting
      @products = products
      @flag = flag
    end

    def get_data
      CSV.generate(headers: true) do |csv|
        csv << headers
        days.times do |i|
          products.each do |pro|
            pro_orders = Order.joins(order_items: :product).where(order_items: { product: pro })
            if flag == true
              orders = begin
                          pro_orders.where('scanned_on >= ? and scanned_on <= ?', (@product_inv_setting.start_time + i.to_s.to_i.days).beginning_of_day, (@product_inv_setting.start_time + i.to_s.to_i.days).end_of_day)
                        rescue
                          []
                        end
              date = (@product_inv_setting.start_time + i.to_s.to_i.days).strftime('%m/%d/%y')
            else
              orders = begin
                          pro_orders.where('scanned_on >= ? and scanned_on <= ?', (DateTime.now.in_time_zone - i.to_s.to_i.days).beginning_of_day, (DateTime.now.in_time_zone - i.to_s.to_i.days).end_of_day)
                        rescue
                          []
                        end
              date = (DateTime.now.beginning_of_day - i.to_s.to_i.days).strftime('%m/%d/%y')
            end
            csv << [date, pro.primary_sku, pro.name.tr(',', ' '), orders.count]
          end
        end
      end
    end

    private

    def headers
      ['DATE FOR DAILY TOTAL', 'SKU', 'PRODUCT NAME', 'DAILY SKU QTY']
    end

    def days
      if flag == true
        @product_inv_setting.start_time ||= 7.days.ago
        @product_inv_setting.end_time ||= Time.current
        days = ((@product_inv_setting&.end_time&.end_of_day - @product_inv_setting&.start_time&.beginning_of_day).to_f / (24 * 60 * 60)).ceil
        days = 0 if days < 0
      else
        days = @product_inv_setting.report_days_option
      end
      days
    end
  end
end
