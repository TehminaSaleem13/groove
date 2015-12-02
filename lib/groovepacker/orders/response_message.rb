module Groovepacker
  module Orders
    module ResponseMessage

      def set_status_and_message(status, message, options=[])
        set_status(status, options)
        set_message(message, options)
      end

      def set_status(status, options)
        options.include?('&') ? (@result['status'] &= status) : (@result['status'] = status)
      end

      def set_message(message, options)
        msg_type = (options & ['error_messages', 'error_msg']).first || "messages"
        if options.include?('push')
          @result[msg_type].push(message)
        else
          @result[msg_type] = message
        end
      end

    end
  end
end
