module Groovepacker
  module Dashboard
    module Stats
      class PackingAccuracy < Groovepacker::Dashboard::Stats::Base

        def summary
          current_month_packing_accuracy = 0
          previous_month_packing_accuracy = 0
          result = {}
          #current month packing accuracy
          if @duration.to_i == -1
            start_time = nil 
          else
            start_time = (DateTime.now - @duration.to_i.days).beginning_of_day 
          end
          end_time = DateTime.now.end_of_day
          current_month_packing_accuracy = 
            get_overall_packing_accuracy_stats(start_time, end_time)


          if @duration.to_i != -1    
            #previous month packed items
            start_time = (DateTime.now - (2*(@duration.to_i)).days).beginning_of_day 
            end_time = (DateTime.now - (@duration.to_i - 1).days).end_of_day
            previous_month_packing_accuracy = 
              get_overall_packing_accuracy_stats(start_time, end_time)

            result = {
              current_period: current_month_packing_accuracy.round(2),
              previous_period: previous_month_packing_accuracy.round(2),
              delta: (current_month_packing_accuracy - previous_month_packing_accuracy).round(2)
            }
          else
            result = {
              current_period: current_month_packing_accuracy.round(2),
              previous_period: previous_month_packing_accuracy.round(2),
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
          
          # if @duration == -1
          #   start_time = nil
          # else
          #   start_time = (DateTime.now - @duration.to_i.days).beginning_of_day 
          # end
          # end_time = DateTime.now.end_of_day

          @users.each_with_index do |user, index|
            stat = {}
            stat[:key] = user.username
            stat[:color] = "#" + pallete.get(index)
            stat[:values] = get_packing_stats(user)
            results.push(stat)
          end
          results
        end
        

        private

          def get_packing_stats(user)
            stats_result = []
            start_time = (DateTime.now - @duration.days).beginning_of_day
            end_time = DateTime.now.end_of_day
            if @duration == -1
              orders = Order.where('scanned_on < ?', end_time).where(packing_user_id: user.id).order(
                scanned_on: :ASC).group('date(scanned_on)').count
            else
              orders = Order.where(scanned_on: start_time..end_time).where(
                packing_user_id: user.id).order(
                scanned_on: :ASC).group('date(scanned_on)').count
            end

            orders.each do |order|
              order[0] = order[0].to_time.to_i
              stats_result.push(order)
            end

            stats_result
          end

          def get_overall_packing_accuracy_stats(start_time, end_time)
            if start_time.nil?
              orders = Order.where(status: 'scanned').where('scanned_on < ?', end_time)
            else
              orders = Order.where(status: 'scanned').where(scanned_on: start_time..end_time)
            end
            total_items_count = 0
            total_incorrect = 0
            orders.each do |order|
              total_items_count = total_items_count + order.order_items.count
              if !order.order_exception.nil? && 
                ["missing_item", "incorrect_item", "qty_related"].include?(order.order_exception.reason)
                total_incorrect = total_incorrect + 1
              end
            end
            total_incorrect == 0 ? 100 : 
              ((total_items_count - total_incorrect).to_f/ total_items_count) * 100
          end
      end
    end
  end
end