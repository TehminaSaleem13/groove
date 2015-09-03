module Groovepacker
  module Dashboard
    module Stats
      class Exception
        def initialize (user_id)
          @user_id = user_id
          @exceptions_considered = ["qty_related", "incorrect_item", "missing_item"]
        end

        def most_recent
          results = []
          exceptions = []

          if @user_id.nil?
            exceptions = OrderException.where("reason IN (?)",
                                              @exceptions_considered).order(created_at: :desc).all
          else
            exceptions = OrderException.where(
              user_id: @user_id).where("reason IN (?)",
                                       @exceptions_considered).order(created_at: :desc)
          end

          percentages = get_percentages(exceptions)

          exceptions.each do |exception|
            except = {}
            except[:created_at] = exception.created_at
            except[:description] = exception.description
            except[:increment_id] = exception.order.increment_id
            except[:order_id] = exception.order_id
            except[:frequency] = percentages[exception.reason]
            results << except
          end

          results
        end

        def by_frequency
          results = []
          exceptions = []

          if @user_id.nil?
            exceptions = OrderException.where("reason IN (?)", @exceptions_considered)
          else
            exceptions = OrderException.where(user_id: @user_id).where(
              "reason IN (?)", @exceptions_considered)
          end

          percentages = get_percentages(exceptions)

          exceptions.each do |exception|
            except = {}
            except[:created_at] = exception.created_at
            except[:description] = exception.description
            except[:increment_id] = exception.order.increment_id
            except[:order_id] = exception.order_id
            except[:frequency] = percentages[exception.reason]
            results << except
          end

          results.sort_by { |k| k[:frequency] }.reverse!
        end

        private

        def get_percentages(exceptions)
          percentages = {}
          @exceptions_considered.each do |exception|
            percentages[exception] = exceptions.where(reason: exception).count
          end

          percentages.each do |key, value|
            percentages[key] = ((value.to_f * 100)/ exceptions.count).round(2)
          end

          percentages
        end

        attr_accessor :user_id, :exceptions_considered
      end
    end
  end
end
