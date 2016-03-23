module Groovepacker
  module Orders
    class OrdersException < Groovepacker::Orders::Base

      def record_exception(order, tenant)
        @order = order
        @tenant = tenant
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

      def add_edit_order_items(order)
        unless @current_user.can? 'add_edit_order_items'
          set_status_and_message(false, 'Couldn\'t rollback because you can not add or edit order items', ['push'])
          return @result
        end

        #Items
        destroy_object_if_not_defined(order.order_items, @params[:single]['items'], 'items')
        
        add_update_order_item(order)
        
        #activity
        #As activities only get added, no updating or adding required
        activities = OrderActivity.where(:order_id => @params[:single]['basicinfo']['id'])
        destroy_object_if_not_defined(activities, @params[:single]['activities'], 'activities')
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
            stat_stream_obj = SendStatStream.new()
            stat_stream_obj.delay(:run_at => 1.seconds.from_now, :queue => 'send_order_exception_#{@order.id}').send_order_exception(@order.id, @tenant)
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
          if @params[:single]['exception'].nil? && order.order_exception.present?
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

        def destroy_object_if_not_defined(objects_array, obj_params, type)
          return if objects_array.blank?
          ids = get_ids_array_from_params(obj_params, type)
          
          objects_array.each do |object|
            found_obj = false
            found_obj = true if ids.include?(object.id)
            object.destroy if found_obj
          end
        end

        def get_ids_array_from_params(obj_params, type=nil)
          if type=='items'
            ids = obj_params.map {|obj| obj['iteminfo']['id']} rescue []
          else
            ids = obj_params.map {|obj| obj["id"]} rescue []
          end
          return ids
        end

        def add_update_order_item(order)
          return if @params[:single]['items'].blank?
          
          @params[:single]['items'].each do |current_item|
            single_item = OrderItem.find_or_create_by_order_id_and_product_id(order.id, current_item['iteminfo']['product_id'])
            single_item = assign_values_to(single_item, current_item, 'item')
            update_product_list(current_item)
          end
        end

        def update_product_list(current_item)
          begin
            current_product = Product.find(current_item['iteminfo']['product_id'])
            values_to_update = { name: current_item['productinfo']['name'], is_skippable: current_item['productinfo']['is_skippable'], location: current_item['location'], sku: current_item['sku']}
            update_list(current_product, values_to_update)
          rescue Exception => e
          end
        end

        def update_list(current_product, values_to_update)
          values_to_update.each do |key, value|
            updatelist(current_product, "#{key.to_s}", value)
          end
        end
    end
  end
end
