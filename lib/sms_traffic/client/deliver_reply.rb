module SmsTraffic
  class Client
    class DeliverReply < Client::Reply
      OK_REPLY = 'OK'.freeze unless const_defined?(:OK_REPLY)

      def ok?
        result == OK_REPLY && message_infos
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

        if phone
          fetch_value(find_message_info(phone), :sms_id)
        elsif message_info.is_a?(Array)
          fetch_value(message_info.first, :sms_id)
        end
      end

      def sms_ids
        message_info = fetch_value(message_infos, :message_info)

        return [fetch_value(message_info, :sms_id)] if message_info&.size == 1
        return [] if message_info.nil?

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
