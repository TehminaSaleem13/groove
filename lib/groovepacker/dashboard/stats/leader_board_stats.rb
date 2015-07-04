module Groovepacker
  module Dashboard
    module Stats
      class LeaderBoardStats
        def initialize
        end

        def compute_leader_board
          1..12.times do |index|
            compute_leader_board_for_order_item_count(index+1)
          end
        end

        def compute_leader_board_for_order_item_count(order_item_count)
          order = Order.find_by_sql("SELECT * from orders where timediff(scanned_on, scan_start_time) = (SELECT MIN(timediff(scanned_on, scan_start_time)) " +
              "FROM orders where orders.id IN(SELECT orders.id from orders INNER JOIN " +
              "order_items ON orders.id = order_items.order_id AND " +
              "orders.scan_start_time != 'NULL' GROUP BY order_items.order_id " +
              "HAVING COUNT(*) = '"+ (order_item_count).to_s+"'))")
              leader_board = LeaderBoard.where(order_item_count: order_item_count)
          if leader_board.empty?
            if order.first.nil?
              LeaderBoard.create(order_item_count: (order_item_count), 
              order_id: nil, scan_time: nil)
            else
              order = order.first
              LeaderBoard.create(order_item_count: (order_item_count), 
                order_id: order.id, scan_time: (order.scanned_on - order.scan_start_time))
            end
          else
            leader_board = leader_board.first
            if !order.first.nil?
              order= order.first
              if leader_board.scan_time > (order.scanned_on - order.scan_start_time)
                leader_board.order = order.id
                leader_board.scan_time = order.scanned_on - order.scan_start_time
                leader_board.order_item_count = order_item_count
                leader_board.save
              end
            else
              leader_board.order_id = nil
              leader_board.scan_time = nil
              leader_board.save
            end
          end
        end

        def list
          results = []
          LeaderBoard.all.each do |row|
            leader_stat = {}
            leader_stat[:order_items_count] = row.order_item_count
            if !row.order.nil?
              leader_stat[:user_name] = User.find(row.order.packing_user_id).name
              leader_stat[:record_date] = row.order.scanned_on
              leader_stat[:increment_id] = row.order.increment_id
              leader_stat[:packing_time] = format_packing_time(row.scan_time)
            else
              leader_stat[:user_name] = "-"
              leader_stat[:record_date] = "-"
              leader_stat[:increment_id] = "-"
              leader_stat[:packing_time] = "-"
            end
            results << leader_stat
          end

          results
        end

        private

        def format_packing_time(scan_time)
          min = scan_time / 60
          sec = scan_time % 60
          [min.to_s.rjust(2, '0'), sec.to_s.rjust(2, '0')].join(":")
        end
      end
    end
  end
end