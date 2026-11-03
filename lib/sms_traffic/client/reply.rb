# Nori loads REXML lazily on the first parse; Reply#parse rescues its exception even with a custom parser.
require 'rexml/parsers/baseparser'

module SmsTraffic
  class Client
    class Reply
      OK_RESULT = 'OK'.freeze
      ERROR_RESULT = 'ERROR'.freeze

      attr_reader :xml, :to_h

      # @raise [MalformedReplyError] the body is not an XML `<reply>` element
      def initialize(xml, xml_parser: SmsTraffic.configuration.xml_parser)
        @xml  = xml.to_s.gsub(/\s+/, ' ')
        @to_h = reply_hash(parse(xml_parser))
        raise MalformedReplyError, xml if @to_h.nil?
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

      def parse(xml_parser)
        xml_parser.parse(@xml)
      rescue REXML::ParseException
        nil
      end

      # An empty `<reply/>` carries no data; a missing `<reply>` element or one holding only text is malformed.
      def reply_hash(parsed)
        return unless parsed.is_a?(Hash) && (parsed.key?('reply') || parsed.key?(:reply))

        reply = fetch_value(parsed, :reply) || {}
        reply if reply.is_a?(Hash)
      end

      def fetch_value(source, key)
        return unless source.is_a?(Hash)

        source.fetch(key.to_s) { source[key.to_sym] }
      end
    end
  end
end
