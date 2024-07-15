require_relative 'deliver_reply'
require_relative 'status_reply'

module SmsTraffic
  class Client
    class Response
      attr_reader :origin, :reply, :code, :body, :message

      REPLY_HASH_MAP = {
        :status  => StatusReply,
        :deliver => DeliverReply,
        nil      => Reply
      }.freeze

      def initialize(response, type: nil)
        @origin = response
        @code = response.code.to_i
        @body = response.body
        @message = response.message

        return unless success?

        @reply = REPLY_HASH_MAP[type].new(body)
      end

      def success?
        code == 200
      end

      def failure?
        !success?
      end

      def error_description
        "#{code}: #{message}" if failure?
      end
    end
  end
end
