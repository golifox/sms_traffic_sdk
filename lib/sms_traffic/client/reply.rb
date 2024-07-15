module SmsTraffic
  class Client
    class Reply
      attr_reader :xml, :hash

      def initialize(xml, xml_parser: SmsTraffic.configuration.xml_parser)
        @xml = xml.gsub!(/\s+/, ' ')
        @hash = fetch_value(xml_parser.parse(xml), :reply)
      end

      private

      def fetch_value(hash, key)
        hash.fetch(key.to_s, nil) || hash.fetch(key.to_sym, nil)
      end
    end
  end
end
