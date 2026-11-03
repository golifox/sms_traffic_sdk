require 'net/http'
require 'openssl'
require 'uri'
require_relative 'client/reply'
require_relative 'client/deliver_reply'
require_relative 'client/status_reply'
require_relative 'client/account_reply'

module SmsTraffic
  class Client
    ENDPOINT = 'multi.php'.freeze
    FILTERED = '[FILTERED]'.freeze
    FILTERED_PARAMS = %i[login password message].freeze
    CONNECTION_ERRORS = [
      SocketError, SystemCallError, IOError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError
    ].freeze
    # Failures that prove the request never reached the server.
    UNREACHABLE_ERRORS = [
      SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH, Net::OpenTimeout
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
        request(DeliverReply, deliver_params(phone, message, originator, **options), read_only: false)
      end

      # @param sms_ids [Array<String>] sms ids
      # @return [StatusReply]
      # @raise [ConnectionError, HttpError, ApiError]
      def status(*sms_ids)
        request(StatusReply, status_params(sms_ids), read_only: true)
      end

      # @return [AccountReply]
      # @raise [ConnectionError, HttpError, ApiError]
      def balance
        request(AccountReply, account_params, read_only: true)
      end

      private

      # Sends the request to the configured host and, when a fallback host is set, repeats it there once if the
      # failure allows it.
      def request(reply_class, form_data, read_only:)
        config = SmsTraffic.configuration
        attempt(reply_class, form_data, config.host)
      rescue Error => e
        raise unless config.fallback_host && retry_on_fallback?(e, read_only:)

        log("retry on #{config.fallback_host} after #{retry_reason(e)}")
        attempt(reply_class, form_data, config.fallback_host)
      end

      # Names the root cause and, for an API error, its code; never the message text.
      def retry_reason(error)
        reason = (error.cause&.class || error.class).to_s
        error.is_a?(ApiError) ? "#{reason} #{error.code}" : reason
      end

      def attempt(reply_class, form_data, host)
        reply = reply_class.new(post(form_data, host))
        raise ApiError.new(reply.code, reply.description) if reply.api_error?

        reply
      end

      # A read-only request is safe to repeat after any transport failure. A deliver is repeated only when the
      # request never reached the server, as the provider may already have queued the SMS otherwise.
      def retry_on_fallback?(error, read_only:)
        case error
        when ApiError then error.retryable?
        when ConnectionError then read_only || UNREACHABLE_ERRORS.any? { |klass| error.cause.is_a?(klass) }
        when HttpError then read_only && error.status >= 500
        else false
        end
      end

      # @param form_data [Hash<Symbol, String|Integer>]
      # @return [String] response body
      def post(form_data, host)
        config = SmsTraffic.configuration
        uri    = URI.join(host, ENDPOINT)
        log("request POST #{uri} #{filter(form_data)}")

        response = perform(uri, form_data, config)
        log("response #{response.code} (#{response.body.to_s.bytesize} bytes)")
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
        operation_params('status').merge(sms_id: sms_ids.join(','))
      end

      def account_params
        operation_params('account')
      end

      def operation_params(operation)
        { login: SmsTraffic.configuration.login, password: SmsTraffic.configuration.password, operation: }
      end
    end
  end
end
