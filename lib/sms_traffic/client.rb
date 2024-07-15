require 'net/http'

module SmsTraffic
  class Client
    class << self
      attr_reader :uri

      # @param phone [String] phone number
      # @param message [String] message
      # @param originator [String] originator (subject)
      # @param options [Hash] additional options
      def deliver(phone, message, originator = nil, **options)
        originator ||= SmsTraffic.configuration.originator
        form_data = deliver_params(phone, message, originator, **options)
        response = perform_request(form_data)
        Response.new(response, type: :deliver)
      end

      # @param message_id [String] message id
      def status(*message_ids)
        form_data = status_params(message_ids)
        response = perform_request(form_data)
        Response.new(response, type: :status)
      end

      private

      # @return [Net::HTTP]
      def connection
        host, logger = SmsTraffic.configuration.values_at(:host, :logger)

        @uri ||= URI.join(host, 'multi.php')
        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = 30
        http.use_ssl = (uri.scheme == 'https')
        http.set_debug_output(logger)
        http
      end

      # @param form_data [Hash<Symbol, String|Integer>]
      # @return [Net::HTTPResponse]
      def perform_request(form_data)
        connection.start do |http|
          request = Net::HTTP::Post.new(uri.request_uri)
          request.set_form_data(form_data)
          http.request(request)
        end
      end

      # @param phone [String] phone number or phone numbers separated by comma
      # @param message [String] message
      # @param originator [String] originator (subject)
      # @param options [Hash] additional options
      # @return [Hash<Symbol, String|Integer>]
      def deliver_params(phone, message, originator, **options)
        {
          login:        SmsTraffic.configuration.login,
          password:     SmsTraffic.configuration.password,
          phones:       phone,
          message:      message,
          want_sms_ids: 1,
          rus:          5,
          originator:   originator
        }.merge(options)
      end

      # @param message_ids [Array<String>] message ids
      # @return [Hash<Symbol, String|Integer>]
      def status_params(*message_ids)
        {
          login:     SmsTraffic.configuration.login,
          password:  SmsTraffic.configuration.password,
          operation: 'status',
          sms_id:    message_ids.join(',')
        }
      end
    end
  end
end
