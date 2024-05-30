# frozen_string_literal: true

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
        @result
      end

      def add_edit_order_items(order)
        # TODO: Limiting Order activities to 100 as on now. (yanjanusa Issue) https://groovepacker.slack.com/archives/C07BB0MEW/p1660154633053269
        unless @current_user.can?('add_edit_order_items')
          handle_insufficient_permissions('Couldn\'t rollback because you cannot add or edit order items')
          return @result
        end

        # Items
        destroy_object_if_not_defined(order.order_items, @params[:single]['items'], 'items')

        add_update_order_item(order)

        # activity
        # As activities only get added, no updating or adding required
        activities = OrderActivity.where(order_id: @params[:single]['basicinfo']['id'])
        if @params[:single]['activities'].count == activities.count
          destroy_object_if_not_defined(activities, @params[:single]['activities'], 'activities')
        end
        @result
      end

      def edit_packing_execptions(order, tenant)
        unless @current_user.can?('edit_packing_ex')
          handle_insufficient_permissions('Couldn\'t rollback because you cannot edit packing exceptions')
          return @result
        end
        # exception
        edit_order_exceptions(order, tenant)
        @result
      end

      private

      def create_or_update_exception
        @exception = @order.order_exception || @order.build_order_exception
        @exception = assign_values_to_exception(@exception)

        if @exception.save
          username = begin
            @params[:assoc][:name]
          rescue StandardError
            ''
          end
          @order.addactivity("Order Exception Associated with #{username} - Recorded", @current_user.name)
          send_exception_data(@order.id, @tenant)
        else
          set_status_and_message(false, 'Could not save order with exception', ['&', ['push']])
        end
      end

      def assign_values_to(single_item_or_ex, current_obj, type = nil)
        new_attr = type == 'item' ? 'product_id' : 'assoc'
        current_ex_or_items_array = type == 'item' ? current_obj['iteminfo'] : current_obj['exception']

        attributes = %w[id created_at updated_at order_id product_id] << new_attr

        if current_ex_or_items_array.present?
          permitted_values = current_ex_or_items_array.permit!.to_h
          permitted_values.each do |key, value|
            single_item_or_ex[key] = value unless attributes.include?(key)
          end
        end

        single_item_or_ex.save! if single_item_or_ex.changed?
      end

      def edit_order_exceptions(order, tenant)
        if @params[:single]['exception'].nil? && order.order_exception.present?
          order.order_exception.destroy
        elsif @params[:single]['exception'].present?
          exception = OrderException.find_or_create_by(order_id: order.id)
          assign_values_to(exception, @params[:single]['exception'], 'exception')
        end
        send_exception_data(order.id, tenant)
      end

      def assign_values_to_exception(exception)
        exception.reason = @params[:reason]
        exception.description = @params[:description]
        exception.user_id = @params[:assoc][:id] if @params[:assoc]&.dig(:id).to_i != 0
        exception
      end

      def handle_insufficient_permissions(message = '')
        @result['status'] &= false
        @result['messages'].push('Insufficient permissions')
        @result['messages'].push(@current_user.role)
        @result['messages'].push(message)
      end

      def destroy_object_if_not_defined(objects_array, obj_params, type)
        return if objects_array.blank?

        ids = get_ids_array_from_params(obj_params, type)

        objects_array.each do |object|
          found_obj = false
          found_obj = true unless ids.include?(object.id)
          object.destroy if found_obj
        end
      end

      def get_ids_array_from_params(obj_params, type = nil)
        if type == 'items'
          begin
            obj_params.map { |obj| obj['iteminfo']['id'] }
          rescue StandardError
            []
          end
        else
          begin
            obj_params.map { |obj| obj['id'] }
          rescue StandardError
            []
          end
        end
      end

      def add_update_order_item(order)
        return if @params[:single]['items'].blank?

        @params[:single]['items'].each do |current_item|
          single_item = OrderItem.find_or_create_by(order_id: order.id,
                                                    product_id: current_item['iteminfo']['product_id'])
          single_item = assign_values_to(single_item, current_item, 'item')
          update_product_list(current_item)
        end
      end

      def update_product_list(current_item)
        current_product = Product.find(current_item['iteminfo']['product_id'])
        values_to_update = { name: current_item['productinfo']['name'],
                             is_skippable: current_item['productinfo']['is_skippable'], location: current_item['location'], sku: current_item['sku'] }
        update_list(current_product, values_to_update)
      rescue Exception => e
      end

      def update_list(current_product, values_to_update)
        values_to_update.each do |key, value|
          updatelist(current_product, key.to_s, value)
        end
      end

      def send_exception_data(order_id, tenant)
        stat_stream_obj = SendStatStream.new
        stat_stream_obj.delay(run_at: 1.seconds.from_now, queue: "send_order_exception_#{tenant}_#{order_id}", priority: 95).send_order_exception(
          order_id, tenant
        )
      end
    end
  end
end
