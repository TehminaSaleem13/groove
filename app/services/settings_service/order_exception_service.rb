module SettingsService
  class OrderExceptionService < SettingsService::Base
    attr_reader :current_user, :params, :result, :row_map, :exceptions

    def initialize(current_user: nil, params: nil)
      @current_user = current_user
      @params = params
      @result = {
        'status' => true,
        'messages' => [],
        'data' => nil,
        'filename' => "groove-order-exceptions-#{Time.now}.csv"
      }
      @row_map = {
        order_number: '', order_date: '', scanned_date: '',
        packing_user: '', reason: '', description: '',
        associated_user: '', total_packed_items: '',
        total_clicked_items: ''
      }
      @exceptions = OrderException.where(
        updated_at: Time.parse(params[:start])..Time.parse(params[:end])
      )
    end

    def call
      validate_params
      if current_user.can? 'view_packing_ex'
        generate_csv
      else
        result['status'] = false
        result['messages'].push('You do not have enough permissions to view packing exceptions')
      end

      do_if_status_false
      super
    end

    private

    def validate_params
      if params[:start].nil? || params[:end].nil?
        result['status'] = false
        result['messages'].push('We need a start and an end time')
      end
    end

    def do_if_status_false
      unless result['status']
        @result['data'] = CSV.generate do |csv|
          csv << result['messages']
        end
        @result['filename'] = 'error.csv'
      end
    end

    def generate_csv
      require 'csv'
      @result['data'] = CSV.generate do |csv|
        csv << row_map.keys
        exceptions.each do |exception|
          single_row = row_map.dup
          generate_single_record(exception, single_row)
          csv << single_row.values
        end
      end
    end

    def generate_single_record(exception, single_row)
      order = exception.order
      user = exception.user

      push_order_data(single_row, order)

      single_row[:reason] = exception.reason
      single_row[:description] = exception.description

      push_user_data(single_row, user, order)
    end

    def push_order_data(single_row, order)
      single_row[:order_number],
      single_row[:order_date],
      single_row[:scanned_date],
      single_row[:order_item_count],
      single_row[:click_scanned_items] = order.as_json(
        only: [
          :increment_id, :order_placed_time, :scanned_on,
          :scanned_items_count, :clicked_items_count
        ]
      ).values
    end

    def push_user_data(single_row, user, order)
      single_row[:associated_user] = user && "#{user.name} (#{user.username})"
      packing_user = User.where(id: order.packing_user_id).first
      single_row[:packing_user] = packing_user &&
                                  "#{packing_user.name} (#{packing_user.username})"
    end
  end
end
