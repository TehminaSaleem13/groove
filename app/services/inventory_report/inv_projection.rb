# frozen_string_literal: true

module InventoryReport
  class InvProjection
    attr_accessor :products

    def initialize(product_inv_setting, products)
      @product_inv_setting = product_inv_setting
      @products = products
    end

    def get_data
      set_start_end_time_if_not_set

      CSV.generate(headers: true) do |csv|
        csv << headers
        joined_orders = Order.includes(order_items: [{ order_item_kit_products: [:product_kit_skus] }, :product])
        products.each do |pro|
          pro_orders = joined_orders.where(order_items: { product: pro }).or(joined_orders.where(order_items: { order_item_kit_products:  { product_kit_skus: { option_product_id: pro.id }}})).distinct
          inv = pro.product_inventory_warehousess

          orders_count = pro_orders.where('scanned_on >= ? and scanned_on <= ?', @product_inv_setting.start_time.beginning_of_day, @product_inv_setting.end_time.end_of_day).count

          available_inv = inv.map(&:available_inv).sum
          quantity_on_hand = inv.map(&:quantity_on_hand).sum

          row = ["#{start_time} to #{end_time}", pro.primary_sku.to_s, pro.name.tr(',', ' ').to_s, orders_count]
          row << get_orders_count(pro_orders)
          row << get_projected_days_remaining(available_inv, restock_lead_time(pro), pro_orders)
          row << [available_inv, quantity_on_hand, pro.product_cats[0]&.category, inv[0]&.location_primary, inv[0]&.location_secondary, inv[0]&.location_tertiary, restock_lead_time(pro)]

          csv << row.flatten
        end
      end
    end

    private

    def set_start_end_time_if_not_set
      @product_inv_setting.start_time ||= 7.days.ago
      @product_inv_setting.end_time ||= Time.current
    end

    def get_projected_days_remaining(available_inv, rlt, pro_orders)
      orders_count = get_orders_count(pro_orders)
      projected_days_remaining = [pro_orders.count.zero? ? 0 : (((available_inv.to_f / (pro_orders.count.to_f / days)) - rlt.to_f)).round()]
      [14, 30, 45, 60, 90].each_with_index do |day_count, i|
        projected_days_remaining << (orders_count[i].zero? ? 0 : ((available_inv.to_f / (orders_count[i].to_f / day_count)) - rlt.to_f)).round()
      end
      projected_days_remaining
    end

    def get_orders_count(pro_orders)
      counts = []
      [14, 30, 45, 60, 90].each do |day_count|
        counts << pro_orders.where('scanned_on >= ?', Time.now - day_count.days).count
      end
      counts
    end

    def restock_lead_time(product)
      product.restock_lead_time || 0
    end

    def start_time
      @product_inv_setting&.start_time&.strftime('%m-%d-%Y')
    end

    def end_time
      @product_inv_setting&.end_time&.strftime('%m-%d-%Y')
    end

    def headers
      ['DATE RANGE', 'SKU', 'PRODUCT NAME', 'SELECTED RANGE QTY SCANNED', 'PAST 14D QTY SCANNED', 'PAST 30D QTY SCANNED', 'PAST 45D QTY SCANNED', 'PAST 60D QTY SCANNED', 'PAST 90D QTY SCANNED', 'SELECTED RANGE PROJ DAYS REMAINING', '14D RANGE PROJ DAYS REMAINING', '30D RANGE PROJ DAYS REMAINING', '45D RANGE PROJ DAYS REMAINING', '60D RANGE PROJ DAYS REMAINING', '90D RANGE PROJ DAYS REMAINING', 'CURRENT AVAILABLE', 'CURRENT QOH', 'CATEGORY', 'LOCATION1', 'LOCATION2', 'LOCATION3', 'RESTOCK LEAD TIME']
    end

    def days
      ((@product_inv_setting&.end_time&.end_of_day - @product_inv_setting&.start_time&.beginning_of_day).to_f  / (24 * 60 * 60)).ceil
    rescue StandardError
      7
    end
  end
end
