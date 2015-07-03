module Groovepacker
  module Dashboard
    module Stats
      class Exception
        def initialize (user_id)
          @user_id = user_id
        end

        def most_recent
          results = []
          exceptions = []

          if @user_id.nil?
            exceptions = OrderException.order(created_at: :desc).all
          else
            exceptions = OrderException.where(user_id: @user_id).order(created_at: :desc)
          end

          exceptions.each do |exception|
            except = {}
            except[:created_at] = exception.created_at
            except[:description] = exception.description
            except[:increment_id] = exception.order.increment_id
            except[:order_id] = exception.order_id
            except[:frequency] = "-"
            results << except
          end

          results
        end

        def by_frequency
          results = []
          exceptions = []

          if @user_id.nil?
            exceptions = OrderException.all
          else
            exceptions = OrderException.where(user_id: @user_id)
          end

          exceptions.each do |exception|
            except = {}
            except[:created_at] = exception.created_at
            except[:description] = exception.description
            except[:increment_id] = exception.order.increment_id
            except[:order_id] = exception.order_id
            except[:frequency] = "-"
            results << except
          end

          results
        end

        attr_accessor :user_id
      end
    end
  end
end