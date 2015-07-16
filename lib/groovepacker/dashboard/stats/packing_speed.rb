module Groovepacker
  module Dashboard
    module Stats
      class PackingSpeed < Groovepacker::Dashboard::Stats::Base

        def summary
          current_month_packing_speed = 0
          previous_month_packing_speed = 0
          result = {}
          #current month packed items
          if @duration.to_i == -1
            start_time = nil 
          else
            start_time = (DateTime.now - @duration.to_i.days).beginning_of_day 
          end
          end_time = DateTime.now.end_of_day
          current_month_packing_speed = 
            get_overall_packing_speed_stats(start_time, end_time)


          if @duration.to_i != -1    
            #previous month packed items
            start_time = (DateTime.now - (2*(@duration.to_i)).days).beginning_of_day 
            end_time = (DateTime.now - (@duration.to_i - 1).days).end_of_day
            previous_month_packing_speed = 
              get_overall_packing_speed_stats(start_time, end_time)

            result = {
              current_period: current_month_packing_speed,
              previous_period: previous_month_packing_speed,
              delta: (previous_month_packing_speed - current_month_packing_speed).round(2)
            }
          else
            result = {
              current_period: current_month_packing_speed,
              previous_period: previous_month_packing_speed,
              delta: '-'
            }
          end
          result        
        end

        def detail
          results = []
          @users = User.all

          pallete = Groovepacker::Dashboard::Color::Pallete.new(
            @users.count, "006699")
          
          if @duration == -1
            start_time = nil
          else
            start_time = (DateTime.now - @duration.to_i.days).beginning_of_day 
          end
          end_time = DateTime.now.end_of_day

          @users.each_with_index do |user, index|
            stat = {}
            stat[:key] = user.username
            stat[:color] = "#" + pallete.get(index)
            stat[:values] = get_packing_speed_stats(user, start_time, end_time)
            results.push(stat)
          end
          results
        end
        

        private

          def get_overall_packing_speed_stats(start_time, end_time)
            if start_time.nil?
              orders = Order.where(status: 'scanned').where('scanned_on < ?', end_time)
            else
              orders = Order.where(status: 'scanned').where(scanned_on: start_time..end_time)
            end
            total_time = 0.0
            total_count = 0
            orders.each do |order|
              unless order.scan_start_time.nil? || order.scanned_on.nil?
                total_count = total_count + 1
                total_time = total_time + 
                  (order.scanned_on - order.scan_start_time).to_i
              end
            end
            total_count == 0 ? 0 : (total_time / total_count).round(2)
          end


          def get_packing_speed_stats(user, start_time, end_time)
            stats_result = []
            start_time = (DateTime.now - @duration.days).beginning_of_day
            end_time = DateTime.now.end_of_day
            if @duration == -1
              orders = Order.where('scanned_on < ?', end_time).where(packing_user_id: user.id).order(
                scanned_on: :ASC).group('date(scanned_on)').count
            else
              orders = Order.where(scanned_on: start_time..end_time).where(packing_user_id: user.id).order(scanned_on: :ASC).group('date(scanned_on)').average('packing_score')
            end

            orders.each do |order|
              order[0] = order[0].to_time.to_i
              stats_result.push(order)
            end

            stats_result
          end
          # def get_packed_item_stats(user, start_time, end_time)
          #   stats_result = []

          #   if start_time == nil
          #     orders = Order.where('scanned_on < ?', end_time).where(
          #       packing_user_id: user.id).order(
          #       scanned_on: :ASC).group('date(scanned_on)')
          #     scanned_dates = Order.where('scanned_on < ?', end_time).where(
          #       packing_user_id: user.id).order(
          #       scanned_on: :ASC).group('date(scanned_on)').pluck(:scanned_on)
          #   else
          #     orders = Order.where(scanned_on: start_time..end_time).where(
          #       packing_user_id: user.id).order(
          #       scanned_on: :ASC).group('date(scanned_on)')
          #     scanned_dates = Order.where(scanned_on: start_time..end_time).where(
          #       packing_user_id: user.id).order(
          #       scanned_on: :ASC).group('date(scanned_on)').pluck(:scanned_on)
          #   end

          #   scanned_dates.each_with_index do |scanned_date, index|
          #     scanned_orders = Order.where(scanned_on: scanned_date.beginning_of_day..scanned_date.end_of_day).where(packing_user_id: user.id)
          #     count = 0
          #     puts scanned_orders.inspect
          #     scanned_orders.each do |scanned_order|
          #       count = count + scanned_order.order_items.count
          #     end
          #     stats_result.push([scanned_date.to_time.to_i, count])
          #   end

          #   stats_result
          # end
      end
    end
  end
end