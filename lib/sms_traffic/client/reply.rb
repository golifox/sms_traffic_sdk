module SmsTraffic
  class Client
    class Reply
      OK_RESULT = 'OK'.freeze
      ERROR_RESULT = 'ERROR'.freeze

      attr_reader :xml, :to_h

      def initialize(xml, xml_parser: SmsTraffic.configuration.xml_parser)
        @xml = xml.gsub(/\s+/, ' ')
        parsed = fetch_value(xml_parser.parse(@xml), :reply)
        @to_h  = parsed.is_a?(Hash) ? parsed : {}
      end

      def result
        fetch_value(to_h, :result)
      end

      def code
        fetch_value(to_h, :code)
      end

      def description
        fetch_value(to_h, :description)
      end

      # The provider documents `ERROR` but its example replies `ERRO`, so any result other than OK is an error.
      def api_error?
        !result.nil? && result != OK_RESULT
      end

      private

      def fetch_value(source, key)
        return unless source.is_a?(Hash)

        source.fetch(key.to_s) { source[key.to_sym] }
      end
    end
  end
end
