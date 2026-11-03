module SmsTraffic
  class Client
    class Reply
      ERROR_RESULT = 'ERROR'.freeze

      attr_reader :xml, :to_h

      def initialize(xml, xml_parser: SmsTraffic.configuration.xml_parser)
        @xml  = xml.gsub(/\s+/, ' ')
        @to_h = fetch_value(xml_parser.parse(@xml), :reply) || {}
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

      def api_error?
        result == ERROR_RESULT
      end

      private

      def fetch_value(source, key)
        return unless source.is_a?(Hash)

        source.fetch(key.to_s) { source[key.to_sym] }
      end
    end
  end
end
