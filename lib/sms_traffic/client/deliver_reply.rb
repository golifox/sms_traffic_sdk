module SmsTraffic
  class Client
    class DeliverReply < Client::Reply
      OK_REPLY = 'OK'.freeze unless const_defined?(:OK_REPLY)

      def ok?
        fetch_value(hash, :result) == OK_REPLY
      rescue NoMethodError
        false
      end

      def error?
        !ok?
      end

      def result
        fetch_value(hash, :result)
      end

      def code
        fetch_value(hash, :code)
      end

      def description
        fetch_value(hash, :description)
      end

      def message_infos
        fetch_value(hash, :message_infos)
      end

      def sms_id(phone = nil)
        message_info = fetch_value(message_infos, :message_info)
        return fetch_value(message_info, :sms_id) if message_info.is_a?(Hash) || message_info.nil?

        raise ArgumentError, 'phone is required' unless phone

        fetch_value(find_message_info(phone), :sms_id)
      end

      def sms_ids
        message_info = fetch_value(message_infos, :message_info)

        return [fetch_value(message_info, :sms_id)] if message_info.size == 1

        message_info.each_with_object({}) do |info, hash|
          hash[fetch_value(info, :phone)] = fetch_value(info, :sms_id)
        end
      end

      def error_description
        "#{result}: code: #{code}, description: #{description}" if error?
      end

      private

      def find_message_info(phone)
        fetch_value(message_infos, :message_info).find { |info| fetch_value(info, :phone) == phone }
      end
    end
  end
end
