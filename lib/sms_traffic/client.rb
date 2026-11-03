require 'net/http'
require 'openssl'
require 'uri'
require_relative 'client/reply'
require_relative 'client/deliver_reply'
require_relative 'client/status_reply'

module SmsTraffic
  class Client
    ENDPOINT = 'multi.php'.freeze
    FILTERED = '[FILTERED]'.freeze
    FILTERED_PARAMS = %i[login password message].freeze
    CONNECTION_ERRORS = [
      SocketError, SystemCallError, IOError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError
    ].freeze

    class << self
      # @param phone [String] phone number or phone numbers separated by comma
      # @param message [String] message
      # @param originator [String] originator (subject), defaults to the configured one
      # @param options [Hash] additional options
      # @return [DeliverReply]
      # @raise [ConnectionError, HttpError, ApiError]
      def deliver(phone, message, originator = nil, **options)
        originator ||= SmsTraffic.configuration.originator
        build_reply(DeliverReply, post(deliver_params(phone, message, originator, **options)))
      end

      # @param sms_ids [Array<String>] sms ids
      # @return [StatusReply]
      # @raise [ConnectionError, HttpError, ApiError]
      def status(*sms_ids)
        build_reply(StatusReply, post(status_params(sms_ids)))
      end

      private

      def build_reply(reply_class, body)
        reply = reply_class.new(body)
        raise ApiError.new(reply.code, reply.description) if reply.api_error?

        reply
      end

      # @param form_data [Hash<Symbol, String|Integer>]
      # @return [String] response body
      def post(form_data)
        config = SmsTraffic.configuration
        uri    = URI.join(config.host, ENDPOINT)
        log("request POST #{uri} #{filter(form_data)}")

        response = perform(uri, form_data, config)
        log("response #{response.code} #{response.body}")
        successful_body(response)
      rescue *CONNECTION_ERRORS => e
        raise ConnectionError, "#{e.class}: #{e.message}"
      end

      def successful_body(response)
        raise HttpError.new(response.code.to_i, response.body) unless response.is_a?(Net::HTTPSuccess)

        response.body
      end

      def perform(uri, form_data, config)
        options = { use_ssl: uri.scheme == 'https', open_timeout: config.open_timeout,
                    read_timeout: config.read_timeout }
        Net::HTTP.start(uri.host, uri.port, **options) do |http|
          request = Net::HTTP::Post.new(uri.request_uri)
          request.set_form_data(form_data)
          http.request(request)
        end
      end

      def log(line)
        config = SmsTraffic.configuration
        config.logger.debug("[SmsTraffic] #{line}") if config.debug
      end

      def filter(form_data)
        form_data.to_h { |key, value| [key, FILTERED_PARAMS.include?(key) ? FILTERED : value] }
      end

      def deliver_params(phone, message, originator, **options)
        {
          login:        SmsTraffic.configuration.login,
          password:     SmsTraffic.configuration.password,
          phones:       phone,
          message:,
          want_sms_ids: 1,
          rus:          5,
          originator:
        }.merge(options)
      end

      def status_params(sms_ids)
        {
          login:     SmsTraffic.configuration.login,
          password:  SmsTraffic.configuration.password,
          operation: 'status',
          sms_id:    sms_ids.join(',')
        }
      end
    end
  end
end
