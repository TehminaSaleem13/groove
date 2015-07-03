module Groovepacker
  module Dashboard
    module Stats
      class LeaderBoard
        def initialize
        end

        def list
          results = []

          User.all.each do |user|
            order = Order.find_by_sql("SELECT MIN(timediff(scanned_on, scan_start_time)), id FROM `orders` WHERE `orders`.`status` = 'scanned' AND 
  `orders`.`packing_user_id` = "+ user.id.to_s + " AND orders.scan_start_time != 'NULL'")
            leader_stat = {}
            if !order.first.nil? && !order.first.id.nil?
              order = Order.find(order.first.id)
              leader_stat[:order_items] = order.order_items.count
              leader_stat[:increment_id] = order.increment_id
              leader_stat[:packing_time] = order.scanned_on - order.scan_start_time
              leader_stat[:user_name] = user.name
              leader_stat[:record_date] = order.scanned_on
            else
              leader_stat[:order_items] = "-"
              leader_stat[:increment_id] = "-"
              leader_stat[:packing_time] = "-"
              leader_stat[:user_name] = user.name
              leader_stat[:record_date] = "-"
            end
            # order = Order.where(status: 'scanned').where(
            #   packing_user_id: user.id).select(
            #   'MIN(timediff(scanned_on, scan_start_time)), id')
            # leader_stat = {}
            # leader_stat[:order_items] = order.
            results << leader_stat
          end

          puts results.inspect
          # if @user_id.nil?
          #   exceptions = OrderException.order(created_at: :desc).all
          # else
          #   exceptions = OrderException.where(user_id: @user_id).order(created_at: :desc)
          # end

          # exceptions.each do |exception|
          #   except = {}
          #   except[:created_at] = exception.created_at
          #   except[:description] = exception.description
          #   except[:increment_id] = exception.order.increment_id
          #   except[:order_id] = exception.order_id
          #   except[:frequency] = "-"
          #   results << except
          # end

          results
        end
      end
    end
  end
end