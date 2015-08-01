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
          avg_stats = []

          pallete = Groovepacker::Dashboard::Color::Pallete.new
          
          # if @duration == -1
          #   start_time = nil
          # else
          #   start_time = (DateTime.now - @duration.to_i.days).beginning_of_day 
          # end
          # end_time = DateTime.now.end_of_day

          @users.each_with_index do |user, index|
            stat = {}
            stat[:key] = user.username
            stat[:color] = pallete.get(index)
            result = get_packing_stats(user)
            stat[:values] = result[:packing_accuracy_stats]
            avg_stats.push(key: user.username,
                           avg_packing_accuracy: result[:avg_packing_accuracy])
            results.push(stat)
          end
          {avg_stats: avg_stats, daily_stats: results}
        end
        

        private

          def get_packing_stats(user)
            stats_result = []
            start_time = (DateTime.now - @duration.days).beginning_of_day
            end_time = DateTime.now.end_of_day
            avg_packing_accuracy = 0
            total_items_count = 0
            total_exceptions_count = 0

            if @duration == -1
              order_scanned_on_predicate = "orders.scanned_on <= '#{end_time.utc.to_formatted_s(:db)}'"
            else
              order_scanned_on_predicate = "orders.scanned_on BETWEEN '#{start_time.utc.to_formatted_s(:db)}' AND
                '#{end_time.utc.to_formatted_s(:db)}'"
            end

            order_items_result = ActiveRecord::Base.connection.exec_query("SELECT date(orders.scanned_on) AS date_scanned_on,
            COUNT(*) AS order_item_count FROM orders
            INNER JOIN order_items ON order_items.order_id = orders.id WHERE orders.packing_user_id = #{user.id}
            AND (#{order_scanned_on_predicate})
            GROUP BY date(scanned_on)")

            order_exceptions_result = ActiveRecord::Base.connection.exec_query("SELECT date(orders.scanned_on) AS date_scanned_on,
            COUNT(*) AS order_exception_count FROM orders
            INNER JOIN order_exceptions ON order_exceptions.order_id = orders.id WHERE orders.packing_user_id = 17
            AND (#{order_scanned_on_predicate})
            GROUP BY date(scanned_on)")

            order_items_result.rows.each do |order|
              exception_count = get_order_exception(order_exceptions_result, order[0])
              percent = 100 - (exception_count.to_f/order[1].to_f)
              order[0] = order[0].to_time.to_i
              order.push(order[1])
              order.push(exception_count)
              order[1] = percent
              total_items_count = total_items_count + order[2]
              total_exceptions_count = total_exceptions_count + order[3]
              stats_result.push(order)
            end
            {avg_packing_accuracy: compute_avg_packing_accuracy(total_exceptions_count, total_items_count),
             packing_accuracy_stats: stats_result}
          end

          def compute_avg_packing_accuracy(total_exceptions_count, total_items_count)
            ((total_items_count == 0 || total_items_count==nil) ? 0 : (100 -
                total_exceptions_count.to_f/total_items_count.to_f).round(2))
          end

          def get_order_exception(order_exceptions, date)
            order_exceptions.rows.each do |order_ex|
              if order_ex[0] == date
                return order_ex[1]
              end
            end
            return 0
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