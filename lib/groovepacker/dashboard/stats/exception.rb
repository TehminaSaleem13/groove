module Groovepacker
  module Dashboard
    module Stats
      class Exception
        def initialize(user_id)
          @user_id = user_id
          @exceptions_considered = %w(qty_related incorrect_item missing_item)
          @results = []
          @exceptions = []
        end

        def most_recent
          if @user_id.nil?
            @exceptions = OrderException.where(
              'reason IN (?)', @exceptions_considered).order(created_at: :desc)
          else
            @exceptions = OrderException.where(
              user_id: @user_id).where(
                'reason IN (?)', @exceptions_considered).order(
                  created_at: :desc)
          end
          build_exception_data

          @results.reverse
        end

        def by_frequency
          if @user_id.nil?
            @exceptions = OrderException.where(
              'reason IN (?)', @exceptions_considered)
          else
            @exceptions = OrderException.where(user_id: @user_id).where(
              'reason IN (?)', @exceptions_considered)
          end
          build_exception_data

          @results.sort_by { |k| k[:frequency] }.reverse!
        end

        private

        def get_percentages(exceptions)
          percentages = {}
          @exceptions_considered.each do |exception|
            percentages[exception] = exceptions.where(reason: exception).count
          end

          percentages.each do |key, value|
            percentages[key] = ((value.to_f * 100) / exceptions.count).round(2)
          end

          percentages
        end

        def build_exception_data
          percentages = get_percentages(@exceptions)

          @exceptions.each do |exception|
            except = access_data(exception, percentages)

            @results << except
          end
        end

        def access_data(exception, percentages)
          order = Order.find(exception.order_id)
          {
            recorded_at: exception.created_at,
            description: exception.description.try(:strip),
            increment_id: exception.order.increment_id,
            order_id: exception.order_id,
            reason: exception.reason,
            frequency: percentages[exception.reason],
            created_at: order.order_placed_time
          }
        end

        attr_accessor :user_id, :exceptions_considered
      end
    end
  end
end
