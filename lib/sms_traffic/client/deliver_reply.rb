module SmsTraffic
  class Client
    class DeliverReply < Reply
      OK_RESULT = 'OK'.freeze

      # @return [Boolean] result is OK and at least one message was queued
      def ok?
        result == OK_RESULT && !messages.empty?
      end

      def error?
        !ok?
      end

      # @return [Array<Hash>] queued messages as { phone:, sms_id:, push_id: }
      def messages
        @messages ||= message_infos.map do |info|
          { phone: fetch_value(info, :phone), sms_id: fetch_value(info, :sms_id), push_id: fetch_value(info, :push_id) }
        end
      end

      # @return [Array<String>] every sms id in reply order
      def sms_ids
        messages.filter_map { |message| message[:sms_id] }
      end

      # @param phone [String, nil]
      # @return [String, nil] the first sms id, or the first one for the phone
      def sms_id(phone = nil)
        message = phone ? messages.find { |item| item[:phone].to_s == phone.to_s } : messages.first
        message&.fetch(:sms_id)
      end

      def error_description
        "Sms has not been enqueued: #{description}" if error?
      end

      private

      def message_infos
        info = fetch_value(fetch_value(to_h, :message_infos), :message_info)
        info.is_a?(Array) ? info : [info].compact
      end
    end
  end
end
