module Groovepacker
  module Orders
    class OrdersException < Groovepacker::Orders::Base

      def record_exception(order)
        @order = order
        if (@current_user.can?('create_packing_ex') && @order.order_exception.nil?) ||
          (@current_user.can?('edit_packing_ex') && !@order.order_exception.nil?)
          create_or_update_exception
        else
          @result['status'] &= false
          @result['messages'].push('Insufficient permissions')
          @result['messages'].push(@current_user.role)
        end
        return @result
      end

      def edit_packing_execptions(order)
        unless @current_user.can? 'edit_packing_ex'
          set_status_and_message(false, 'Couldn\'t rollback because you can not edit packing exceptions', ['push'])
          return @result
        end
        #exception
        edit_order_exceptions(order)
        return @result
      end

      private
        def create_or_update_exception
          @exception = @order.order_exception
          @exception = assign_values_to_exception
          
          if @exception.save
            username = @params[:assoc][:name] rescue ""
            @order.addactivity("Order Exception Associated with #{username} - Recorded", @current_user.name)
          else
            set_status_and_message(false, 'Could not save order with exception', ['&', ['push']])
          end
        end

        def assign_values_to_exception
          @exception = @order.build_order_exception if @exception.nil?

          @exception.reason = @params[:reason]
          @exception.description = @params[:description]
          
          if !@params[:assoc].nil? && !@params[:assoc][:id] != 0
            @exception.user_id = @params[:assoc][:id]
          end
          @exception
        end

        def edit_order_exceptions(order)
          if @params[:single]['exception'].nil? && order.order_exception.nil?
              order.order_exception.destroy
          elsif @params[:single]['exception'].present?
            exception = OrderException.find_or_create_by_order_id(order.id)
            assign_values_to(exception, @params[:single]['exception'], 'exception')
          end
        end

        def assign_values_to(single_item_or_ex, current_obj, type=nil)
          new_attr = type=='item' ? "product_id" : "accoc"
          current_ex_or_items_array = type=='item' ? current_obj['iteminfo'] : current_obj['exception']

          attributes = ["id", "created_at", "updated_at", "order_id", "product_id"] << new_attr
          current_ex_or_items_array.each do |value|
            single_item_or_ex[value[0]] = value[1] unless attributes.include?(value[0])
          end
          single_item_or_ex.save!
        end
    end
  end
end
