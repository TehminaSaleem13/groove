module Groovepacker
  module Dashboard
    module Stats
      class PackedItem < Groovepacker::Dashboard::Stats::Base

        def summary
          current_month_packed_items = 0
          previous_month_packed_items = 0
          result = {}
          #current month packed items
          if @duration.to_i == -1
            start_time = nil 
          else
            start_time = (DateTime.now - @duration.to_i.days).beginning_of_day 
          end
          end_time = DateTime.now.end_of_day
          current_month_packed_items = 
            get_overall_packed_item_stats(start_time, end_time)


          if @duration.to_i != -1    
            #previous month packed items
            start_time = (DateTime.now - (2*(@duration.to_i)).days).beginning_of_day 
            end_time = (DateTime.now - (@duration.to_i - 1).days).end_of_day
            previous_month_packed_items = 
              get_overall_packed_item_stats(start_time, end_time)

            result = {
              current_period: current_month_packed_items,
              previous_period: previous_month_packed_items,
              delta: current_month_packed_items - previous_month_packed_items
            }
          else
            result = {
              current_period: current_month_packed_items,
              previous_period: previous_month_packed_items,
              delta: '-'
            }
          end
          result        
        end

        def detail
          results = []
          @users = User.all

          pallete = Groovepacker::Dashboard::Color::Pallete.new
          
          if @duration == -1
            start_time = nil
          else
            start_time = (DateTime.now - @duration.to_i.days).beginning_of_day 
          end
          end_time = DateTime.now.end_of_day

          @users.each_with_index do |user, index|
            stat = {}
            stat[:key] = user.username
            stat[:color] = pallete.get(index)
            stat[:values] = get_packed_item_stats(user, start_time, end_time)
            results.push(stat)
          end
          results
        end
        

        private

          def get_overall_packed_item_stats(start_time, end_time)
            if start_time.nil?
              orders = Order.where(status: 'scanned').where('scanned_on < ?', end_time)
            else
              orders = Order.where(status: 'scanned').where(scanned_on: start_time..end_time)
            end
            count = 0
            orders.each do |order|
              count = count + get_scanned_count(order)
            end
            count
          end

          def get_packed_item_stats(user, start_time, end_time)
            stats_result = []

            if start_time == nil
              orders = Order.where('scanned_on < ?', end_time).where(
                packing_user_id: user.id).order(
                'scanned_on ASC').group('date(scanned_on)')
              scanned_dates = Order.where('scanned_on < ?', end_time).where(
                packing_user_id: user.id).order(
                'scanned_on ASC').group('date(scanned_on)').pluck(:scanned_on)
            else
              orders = Order.where(scanned_on: start_time..end_time).where(
                packing_user_id: user.id).order(
                'scanned_on ASC').group('date(scanned_on)')
              scanned_dates = Order.where(scanned_on: start_time..end_time).where(
                packing_user_id: user.id).order(
                'scanned_on ASC').group('date(scanned_on)').pluck(:scanned_on)
            end

            scanned_dates.each_with_index do |scanned_date, index|
              scanned_orders = Order.where(scanned_on: 
                scanned_date.beginning_of_day.utc..scanned_date.end_of_day.utc).where(
                packing_user_id: user.id)
              count = 0
              scanned_orders.each do |scanned_order|
                # puts scanned_order.increment_id
                # puts get_scanned_count(scanned_order).inspect
                count = count + get_scanned_count(scanned_order)
              end
              stats_result.push([scanned_date.to_time.to_i, count])
            end

            stats_result

          end

          def get_scanned_count(order)
            count = 0
            order.order_items.each do |order_item|
              if order_item.product.is_kit == 1
                if order_item.product.kit_parsing == 'single'
                  count = count + order_item.scanned_qty
                elsif order_item.product.kit_parsing == 'individual'
                  count = count + get_individual_kit_qty(order_item)
                else
                  count = count + order_item.single_scanned_qty
                  count = count + get_individual_kit_qty(order_item)
                end
              else
                count = count + order_item.scanned_qty
              end
              # puts order_item.id.inspect
              # puts order_item.product.is_kit.inspect
              # puts order_item.product.kit_parsing.inspect
              # puts count.inspect
            end
            count
          end

          def get_individual_kit_qty(order_item)
            count = 0
            order_item.order_item_kit_products.each do |kit_product|
              count = count + kit_product.scanned_qty
            end
            count
          end

      end
    end
  end
end