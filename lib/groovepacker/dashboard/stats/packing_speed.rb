# module Groovepacker
#   module Dashboard
#     module Stats
#       class PackingSpeed < Groovepacker::Dashboard::Stats::Base

#         def summary
#           current_month_packing_speed = 0
#           previous_month_packing_speed = 0
#           result = {}
#           #current month packed items
#           if @duration.to_i == -1
#             start_time = nil
#           else
#             start_time = (DateTime.now - @duration.to_i.days).beginning_of_day
#           end
#           end_time = DateTime.now.end_of_day
#           current_month_packing_speed =
#             get_overall_packing_speed_stats(start_time, end_time)


#           if @duration.to_i != -1
#             #previous month packed items
#             start_time = (DateTime.now - (2*(@duration.to_i)).days).beginning_of_day
#             end_time = (DateTime.now - (@duration.to_i - 1).days).end_of_day
#             previous_month_packing_speed =
#               get_overall_packing_speed_stats(start_time, end_time)

#             result = {
#               current_period: current_month_packing_speed,
#               previous_period: previous_month_packing_speed,
#               delta: (previous_month_packing_speed - current_month_packing_speed).round(2)
#             }
#           else
#             result = {
#               current_period: current_month_packing_speed,
#               previous_period: previous_month_packing_speed,
#               delta: '-'
#             }
#           end
#           result
#         end

#         def detail
#           results = []
#           avg_stats = []
#           @users = User.all

#           pallete = Groovepacker::Dashboard::Color::Pallete.new

#           if @duration == -1
#             start_time = nil
#           else
#             start_time = (DateTime.now - @duration.to_i.days).beginning_of_day
#           end
#           end_time = DateTime.now.end_of_day

#           @users.each_with_index do |user, index|
#             stat = {}
#             stat[:key] = user.username
#             stat[:color] = pallete.get(index)
#             result = get_packing_speed_stats(user, start_time, end_time)
#             stat[:values] = result[:packing_stats]
#             avg_stats.push(key: user.username,
#                            avg_period_score: result[:avg_period_score])
#             results.push(stat)
#           end

#           {avg_stats: avg_stats, daily_stats: results}
#         end


#         private

#         def get_overall_packing_speed_stats(start_time, end_time)
#           if start_time.nil?
#             orders = Order.where(status: 'scanned').where(
#               'packing_score > 0').where('scanned_on < ?', end_time)
#           else
#             orders = Order.where(status: 'scanned').where(
#               'packing_score > 0').where(scanned_on: start_time..end_time)
#           end
#           total_time = 0.0
#           total_count = 0
#           orders.each do |order|
#             unless order.total_scan_time == 0 || order.total_scan_count == 0
#               total_count = total_count + order.total_scan_count
#               total_time = total_time + order.total_scan_time
#             end
#           end
#           total_count == 0 ? 0 : 100 - ((total_time / total_count).round(2))
#         end


#         def get_packing_speed_stats(user, start_time, end_time)
#           stats_result = []
#           start_time = (DateTime.now - @duration.days).beginning_of_day
#           end_time = DateTime.now.end_of_day
#           total_scan_count = nil
#           avg_period_scan_time = 0
#           avg_period_count = 0

#           # For all duration
#           if @duration == -1
#             scanned_on_predicate = ["scanned_on <= ?", end_time]
#           else
#             scanned_on_predicate = {scanned_on: start_time..end_time}
#           end

#           # compute daily avg score

#           # compute daily  packing time
#           orders = Order.
#             where(scanned_on_predicate).
#             where(packing_user_id: user.id).
#             where('packing_score > 0').
#             order('scanned_on ASC').
#             group('date(scanned_on)').
#             sum('total_scan_count * total_scan_time')

#           # compute total packing items
#           total_scan_count = Order.
#             where(scanned_on: start_time..end_time).
#             where(packing_user_id: user.id).
#             where('packing_score > 0').
#             order('scanned_on ASC').
#             group('date(scanned_on)').
#             sum('total_scan_count')

#           # change to timestamp and compute daily speed score
#           orders.each do |order|
#             count = total_scan_count[order[0]]
#             order[0] = order[0].to_time.to_i
#             avg_period_scan_time = avg_period_scan_time + order[1]
#             avg_period_count = avg_period_count + count
#             order[1] = compute_avg_packing_score(order[1], count)
#             stats_result.push(order)
#           end

#           avg_period_score = compute_avg_packing_score(
#             avg_period_scan_time, avg_period_count)

#           {avg_period_score: avg_period_score, packing_stats: stats_result}
#         end


#         def compute_avg_packing_score(sum, count)
#           ((count == 0 || count==nil) ? 0 : (100 - sum.to_f/count).round(2))
#         end
#         # def get_packed_item_stats(user, start_time, end_time)
#         #   stats_result = []

#         #   if start_time == nil
#         #     orders = Order.where('scanned_on < ?', end_time).where(
#         #       packing_user_id: user.id).order(
#         #       scanned_on: :ASC).group('date(scanned_on)')
#         #     scanned_dates = Order.where('scanned_on < ?', end_time).where(
#         #       packing_user_id: user.id).order(
#         #       scanned_on: :ASC).group('date(scanned_on)').pluck(:scanned_on)
#         #   else
#         #     orders = Order.where(scanned_on: start_time..end_time).where(
#         #       packing_user_id: user.id).order(
#         #       scanned_on: :ASC).group('date(scanned_on)')
#         #     scanned_dates = Order.where(scanned_on: start_time..end_time).where(
#         #       packing_user_id: user.id).order(
#         #       scanned_on: :ASC).group('date(scanned_on)').pluck(:scanned_on)
#         #   end

#         #   scanned_dates.each_with_index do |scanned_date, index|
#         #     scanned_orders = Order.where(scanned_on: scanned_date.beginning_of_day..scanned_date.end_of_day).where(packing_user_id: user.id)
#         #     count = 0
#         #     puts scanned_orders.inspect
#         #     scanned_orders.each do |scanned_order|
#         #       count = count + scanned_order.order_items.count
#         #     end
#         #     stats_result.push([scanned_date.to_time.to_i, count])
#         #   end

#         #   stats_result
#         # end
#       end
#     end
#   end
# end
