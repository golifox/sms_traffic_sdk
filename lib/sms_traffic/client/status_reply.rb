module SmsTraffic
  class Client
    class StatusReply < Reply
      def sms_array
        fetch_value(hash, :sms).is_a?(Array) ? fetch_value(hash, :sms) : [hash]
      end

      def status(sms_id = nil)
        return fetch_value(sms_array.first, :status) if sms_array.size == 1

        raise ArgumentError, 'sms_id is required' if sms_id.nil?

        statuses[sms_id.to_s]
      end

      # @return [Hash] statuses hash (key: sms_id, value: status)
      # @example
      #
      #  {
      #    '1234567890': 'DELIVERED',
      #    '0987654321': 'FAILED'
      #  }
      def statuses
        sms_array.each_with_object({}) do |sms, hash|
          hash[fetch_value(sms, :sms_id)] = fetch_value(sms, :status)
        end.compact
      end

      def error(sms_id = nil)
        return fetch_value(sms_array.first, :error) if sms_array.size == 1

        raise ArgumentError, 'sms_id is required' if sms_id.nil?

        errors[sms_id.to_s]
      end

      def errors
        sms_array.each_with_object({}) do |sms, hash|
          hash[fetch_value(sms, :sms_id)] = fetch_value(sms, :error)&.strip
        end.compact
      end
    end
  end
end
